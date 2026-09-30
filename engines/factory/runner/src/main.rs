//! runwell-runner: claims work from a Runwell factory, runs an AI agent on it in a fresh
//! container, and reports back.
//!
//! It is a client of Runwell's MCP server and nothing more: claim_work, heartbeat_run and
//! finish_run, called with a person's token, so every run is recorded as that person's agent.
//! Runwell decides what to work on, when to stop and what the agent is told (the task comes
//! with each run); the runner puts the repositories in place, starts the agent, keeps the
//! lease alive, enforces the time limit and reads the agent's final JSON block.

use serde_json::{json, Value};
use std::env;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::os::unix::process::CommandExt;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

const VERSION: &str = env!("CARGO_PKG_VERSION");
const DEFAULT_AGENT: &str = "claude -p --output-format json --dangerously-skip-permissions";

const HELP: &str = "runwell-runner: claim work from a Runwell factory and run an AI agent on it

Usage: runwell-runner [options]

  --url URL          Runwell's address (RUNWELL_URL)
  --token TOKEN      a personal token of someone allowed to run the factory (RUNWELL_TOKEN)
  --name NAME        this runner's name, shown on every run (RUNWELL_RUNNER_NAME, else the hostname)
  --image IMAGE      the agent's container image (default runwell-agent)
  --agent COMMAND    the agent command; reads the task on stdin, answers on stdout
                     (default: claude -p --output-format json --dangerously-skip-permissions)
  --workdir DIR      where run directories go (default: the system temp directory)
  --poll SECONDS     how long to wait when there's nothing to claim (default 30)
  --once             claim at most one piece of work, then exit
  --no-container     run the agent directly on this machine (only for trusted work)
  --keep             keep each run's directory afterwards
  --version, --help

Passed to the agent: ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN, and GH_TOKEN (push branches,
open pull requests). Ctrl-C stops the agent, reports the run as failed, then exits.";

struct Config {
    url: String,
    token: String,
    name: String,
    image: String,
    agent: String,
    workdir: PathBuf,
    poll: u64,
    once: bool,
    container: bool,
    keep: bool,
}

/// 0 running, 1 stop (Ctrl-C once), 2 stopped hard.
type Stop = Arc<AtomicU8>;

fn main() {
    let config = match parse_args() {
        Ok(config) => config,
        Err(message) => {
            eprintln!("runwell-runner: {message}\n\nrunwell-runner --help for the options.");
            std::process::exit(2);
        }
    };

    let stop: Stop = Arc::new(AtomicU8::new(0));
    let handler = stop.clone();
    ctrlc::set_handler(move || {
        if handler.fetch_add(1, Ordering::SeqCst) >= 1 {
            eprintln!("\nrunwell-runner: stopping now.");
            std::process::exit(130);
        }
        eprintln!("\nrunwell-runner: stopping after reporting the current run (Ctrl-C again to quit now).");
    })
    .expect("could not handle Ctrl-C");

    let mut runwell = Runwell::new(&config.url, &config.token);
    log(&format!("runwell-runner {VERSION} as “{}” on {}{}", config.name, config.url,
        if config.container { format!(", agent image {}", config.image) } else { ", no container".into() }));

    loop {
        if stop.load(Ordering::SeqCst) > 0 {
            break;
        }
        match runwell.call("claim_work", json!({ "runner": config.name })) {
            Ok(answer) => match answer.pointer("/data/run").filter(|run| run.get("id").is_some()) {
                Some(run) => execute(&mut runwell, &config, run, &stop),
                None => {
                    log(answer["summary"].as_str().unwrap_or("Nothing claimed."));
                    if config.once {
                        break;
                    }
                    sleep_unless_stopped(config.poll, &stop);
                }
            },
            Err(message) => {
                log(&format!("claim failed: {message}"));
                if config.once {
                    std::process::exit(1);
                }
                sleep_unless_stopped(config.poll, &stop);
            }
        }
        if config.once {
            break;
        }
    }
}

// ---------------------------------------------------------------------------------------------
// One run

struct Outcome {
    outcome: &'static str,
    summary: String,
    branch: Option<String>,
    pull_request_url: Option<String>,
    cost_cents: i64,
    input_tokens: i64,
    output_tokens: i64,
}

impl Outcome {
    fn failed(summary: impl Into<String>) -> Self {
        Outcome { outcome: "failed", summary: summary.into(), branch: None, pull_request_url: None, cost_cents: 0, input_tokens: 0, output_tokens: 0 }
    }
}

fn execute(runwell: &mut Runwell, config: &Config, run: &Value, stop: &Stop) {
    let id = run["id"].as_i64().unwrap_or_default();
    let title = run.pointer("/todo/display_name").and_then(Value::as_str).unwrap_or("work");
    log(&format!("run {id}: “{title}”"));

    let dir = config.workdir.join(format!("runwell-run-{id}"));
    let outcome = match prepare(&dir, run) {
        Ok(()) => supervise(runwell, config, run, &dir, stop),
        Err(message) => Some(Outcome::failed(format!("The runner couldn't prepare the run: {message}"))),
    };

    if let Some(outcome) = outcome {
        let mut finish = json!({ "outcome": outcome.outcome, "summary": outcome.summary,
            "cost_cents": outcome.cost_cents, "input_tokens": outcome.input_tokens, "output_tokens": outcome.output_tokens });
        if let Some(branch) = outcome.branch.or_else(|| run["branch"].as_str().map(String::from)) {
            finish["branch"] = json!(branch);
        }
        if let Some(url) = outcome.pull_request_url {
            finish["pull_request_url"] = json!(url);
        }
        match runwell.call("finish_run", json!({ "run_id": id, "finish": finish })) {
            Ok(answer) => log(&format!("run {id}: {}", answer["summary"].as_str().unwrap_or(outcome.outcome))),
            Err(message) => log(&format!("run {id}: couldn't report ({message}); its lease will run out and free the work")),
        }
    }

    if !config.keep {
        let _ = fs::remove_dir_all(&dir);
    }
}

/// The run's directory: the task, a setup script that clones the repositories onto the branch,
/// and the script the container runs.
fn prepare(dir: &Path, run: &Value) -> Result<(), String> {
    let _ = fs::remove_dir_all(dir);
    fs::create_dir_all(dir.join(".home")).map_err(|e| format!("{}: {e}", dir.display()))?;

    let task = run["task"].as_str().ok_or("the run came without a task (was it claimed with this token?)")?;
    fs::write(dir.join("TASK.md"), task).map_err(|e| e.to_string())?;

    let mut setup = String::from(
        "set -e\n\
         git config --global user.name \"${GIT_AUTHOR_NAME:-Runwell agent}\"\n\
         git config --global user.email \"${GIT_AUTHOR_EMAIL:-agent@runwell.invalid}\"\n\
         git config --global credential.helper '!f() { echo username=x-access-token; echo \"password=$GH_TOKEN\"; }; f'\n",
    );
    for repository in run["repositories"].as_array().into_iter().flatten() {
        let commands: Vec<&str> = repository["commands"].as_array().into_iter().flatten().filter_map(Value::as_str).collect();
        if !commands.is_empty() {
            setup.push_str(&format!("( {} )\n", commands.join(" && ")));
        }
    }
    fs::write(dir.join("setup.sh"), setup).map_err(|e| e.to_string())?;
    Ok(())
}

/// Runs the agent and watches it: heartbeats to keep the lease, the time limit, and a person
/// cancelling. None when the run ended on Runwell's side (cancelled), so there's nothing to report.
fn supervise(runwell: &mut Runwell, config: &Config, run: &Value, dir: &Path, stop: &Stop) -> Option<Outcome> {
    let id = run["id"].as_i64().unwrap_or_default();
    let limit = Duration::from_secs(run["time_limit_minutes"].as_u64().unwrap_or(60) * 60);
    let lease = run["lease_minutes"].as_u64().unwrap_or(10) * 60;
    let heartbeat_every = Duration::from_secs((lease / 3).clamp(20, 120));
    let container = format!("runwell-run-{id}");

    let mut child = match start_agent(config, dir, &container) {
        Ok(child) => child,
        Err(message) => return Some(Outcome::failed(format!("The agent didn't start: {message}"))),
    };

    let started = Instant::now();
    let mut last_heartbeat = Instant::now();
    loop {
        match child.try_wait() {
            Ok(Some(status)) => return Some(read_outcome(dir, status.code())),
            Ok(None) => {}
            Err(e) => return Some(Outcome::failed(format!("Lost track of the agent: {e}"))),
        }
        if stop.load(Ordering::SeqCst) > 0 {
            kill(&mut child, config, &container);
            return Some(Outcome::failed("The runner was stopped before the agent finished."));
        }
        if started.elapsed() > limit {
            kill(&mut child, config, &container);
            let mut outcome = read_outcome(dir, None);
            outcome.outcome = "failed";
            outcome.summary = format!("Stopped at the {}-minute limit. {}", limit.as_secs() / 60, outcome.summary);
            return Some(outcome);
        }
        if last_heartbeat.elapsed() >= heartbeat_every {
            last_heartbeat = Instant::now();
            match runwell.call("heartbeat_run", json!({ "run_id": id })) {
                Ok(answer) => {
                    let status = answer.pointer("/data/run/status").and_then(Value::as_str).unwrap_or("running");
                    if status != "running" {
                        log(&format!("run {id}: {status} on Runwell; stopping the agent"));
                        kill(&mut child, config, &container);
                        return None;
                    }
                }
                Err(message) => log(&format!("run {id}: heartbeat failed ({message}); carrying on")),
            }
        }
        thread::sleep(Duration::from_secs(1));
    }
}

fn start_agent(config: &Config, dir: &Path, container: &str) -> Result<Child, String> {
    // Git reads this run's own config (identity, the GitHub credential helper), never the
    // machine's, and the token stays in the environment rather than on disk.
    let script = format!("export GIT_CONFIG_GLOBAL=\"$PWD/.gitconfig\"\n\
        sh setup.sh > setup.log 2>&1 || {{ echo 'setup failed' >> setup.log; exit 90; }}\n\
        {{ {} ; }} < TASK.md > agent.out 2> agent.log\n", config.agent);
    fs::write(dir.join("run.sh"), script).map_err(|e| e.to_string())?;

    let mut command = if config.container {
        let mut command = Command::new("docker");
        command.args(["run", "--rm", "--name", container, "--volume", &format!("{}:/work", dir.display()), "--workdir", "/work",
            "--env", "HOME=/work/.home", "--env", "IS_SANDBOX=1"]);
        if let Some(user) = host_user() {
            command.args(["--user", &user]);
        }
        for key in ["ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN", "GH_TOKEN", "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL"] {
            if env::var_os(key).is_some() {
                command.args(["--env", key]);
            }
        }
        command.args([config.image.as_str(), "sh", "/work/run.sh"]);
        command
    } else {
        let mut command = Command::new("sh");
        command.arg("run.sh").current_dir(dir);
        command
    };
    // Its own process group, so stopping it stops everything the agent started too.
    command.stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).process_group(0);
    command.spawn().map_err(|e| e.to_string())
}

fn kill(child: &mut Child, config: &Config, container: &str) {
    if config.container {
        let _ = Command::new("docker").args(["kill", container]).stdout(Stdio::null()).stderr(Stdio::null()).status();
    }
    let _ = Command::new("kill").args(["-KILL", &format!("-{}", child.id())]).stdout(Stdio::null()).stderr(Stdio::null()).status();
    let _ = child.kill();
    let _ = child.wait();
}

/// What the agent said. Claude Code's JSON output carries the reply, cost and tokens; any other
/// agent's output is read as the reply itself. The reply should end with a JSON block naming the
/// outcome; without one the run counts as failed, since nobody can tell what happened.
fn read_outcome(dir: &Path, exit_code: Option<i32>) -> Outcome {
    let output = read_to_string(&dir.join("agent.out"));
    if exit_code == Some(90) {
        return Outcome::failed(format!("Setting up the repositories failed:\n{}", tail(&read_to_string(&dir.join("setup.log")), 1500)));
    }

    let (reply, cost_cents, input_tokens, output_tokens) = match serde_json::from_str::<Value>(output.trim()) {
        Ok(parsed) if parsed.get("result").is_some() || parsed.get("total_cost_usd").is_some() => {
            let usage = &parsed["usage"];
            let tokens = |key: &str| usage[key].as_i64().unwrap_or(0);
            (
                parsed["result"].as_str().unwrap_or_default().to_string(),
                (parsed["total_cost_usd"].as_f64().unwrap_or(0.0) * 100.0).round() as i64,
                tokens("input_tokens") + tokens("cache_read_input_tokens") + tokens("cache_creation_input_tokens"),
                tokens("output_tokens"),
            )
        }
        _ => (output.clone(), 0, 0, 0),
    };

    let mut outcome = match last_json_block(&reply) {
        Some(block) => Outcome {
            outcome: if block["outcome"].as_str() == Some("succeeded") { "succeeded" } else { "failed" },
            summary: block["summary"].as_str().map(String::from).unwrap_or_else(|| tail(&reply, 1500)),
            branch: block["branch"].as_str().filter(|s| !s.is_empty()).map(String::from),
            pull_request_url: block["pull_request_url"].as_str().filter(|s| s.starts_with("http")).map(String::from),
            cost_cents: 0,
            input_tokens: 0,
            output_tokens: 0,
        },
        None => {
            let said = if reply.trim().is_empty() { tail(&read_to_string(&dir.join("agent.log")), 1500) } else { tail(&reply, 1500) };
            Outcome::failed(format!("The agent ended{} without saying how it went. Its last words:\n{said}",
                exit_code.map(|code| format!(" (exit {code})")).unwrap_or_default()))
        }
    };
    outcome.cost_cents = cost_cents;
    outcome.input_tokens = input_tokens;
    outcome.output_tokens = output_tokens;
    outcome
}

fn last_json_block(text: &str) -> Option<Value> {
    let start = text.rfind("```json")? + "```json".len();
    let end = text[start..].find("```")? + start;
    serde_json::from_str(text[start..end].trim()).ok()
}

// ---------------------------------------------------------------------------------------------
// Runwell's MCP server

struct Runwell {
    endpoint: String,
    token: String,
    next_id: u64,
}

impl Runwell {
    fn new(url: &str, token: &str) -> Self {
        Runwell { endpoint: format!("{}/mcp", url.trim_end_matches('/')), token: token.to_string(), next_id: 0 }
    }

    /// Calls one tool and returns its answer (the structured content), or the error in words.
    fn call(&mut self, tool: &str, arguments: Value) -> Result<Value, String> {
        self.next_id += 1;
        let request = json!({ "jsonrpc": "2.0", "id": self.next_id, "method": "tools/call", "params": { "name": tool, "arguments": arguments } });
        let response = ureq::post(&self.endpoint)
            .set("Authorization", &format!("Bearer {}", self.token))
            .set("Accept", "application/json, text/event-stream")
            .set("User-Agent", &format!("runwell-runner/{VERSION}"))
            .timeout(Duration::from_secs(60))
            .send_json(request);

        let body = match response {
            Ok(response) => response.into_string().map_err(|e| e.to_string())?,
            Err(ureq::Error::Status(401, _)) => return Err("the token was refused (401): make a new one in Settings > Connected apps".into()),
            Err(ureq::Error::Status(code, response)) => return Err(format!("HTTP {code}: {}", tail(&response.into_string().unwrap_or_default(), 300))),
            Err(e) => return Err(e.to_string()),
        };
        let message: Value = serde_json::from_str(&body).map_err(|_| format!("not JSON: {}", tail(&body, 200)))?;
        if let Some(error) = message.get("error") {
            return Err(error["message"].as_str().unwrap_or("error").to_string());
        }
        let result = &message["result"];
        let answer = result.get("structuredContent").cloned()
            .or_else(|| result.pointer("/content/0/text").and_then(Value::as_str).and_then(|text| serde_json::from_str(text).ok()))
            .ok_or_else(|| format!("{tool} answered without content"))?;
        if answer["status"] == "error" {
            let code = answer["code"].as_str().unwrap_or("error");
            return Err(format!("{code}: {}", answer["summary"].as_str().unwrap_or("")));
        }
        Ok(answer)
    }
}

// ---------------------------------------------------------------------------------------------
// Odds and ends

fn parse_args() -> Result<Config, String> {
    let mut args = env::args().skip(1);
    let mut config = Config {
        url: env::var("RUNWELL_URL").unwrap_or_default(),
        token: env::var("RUNWELL_TOKEN").unwrap_or_default(),
        name: env::var("RUNWELL_RUNNER_NAME").ok().filter(|s| !s.is_empty()).unwrap_or_else(hostname),
        image: "runwell-agent".into(),
        agent: DEFAULT_AGENT.into(),
        workdir: env::temp_dir(),
        poll: 30,
        once: false,
        container: true,
        keep: false,
    };
    while let Some(arg) = args.next() {
        let mut value = |name: &str| args.next().ok_or(format!("{name} needs a value"));
        match arg.as_str() {
            "--url" => config.url = value("--url")?,
            "--token" => config.token = value("--token")?,
            "--name" => config.name = value("--name")?,
            "--image" => config.image = value("--image")?,
            "--agent" => config.agent = value("--agent")?,
            "--workdir" => config.workdir = PathBuf::from(value("--workdir")?),
            "--poll" => config.poll = value("--poll")?.parse().map_err(|_| "--poll takes whole seconds")?,
            "--once" => config.once = true,
            "--no-container" => config.container = false,
            "--keep" => config.keep = true,
            "--version" | "-V" => {
                println!("runwell-runner {VERSION}");
                std::process::exit(0);
            }
            "--help" | "-h" => {
                println!("{HELP}");
                std::process::exit(0);
            }
            other => return Err(format!("unknown option {other}")),
        }
    }
    if config.url.is_empty() {
        return Err("say where Runwell is: --url or RUNWELL_URL".into());
    }
    if config.token.is_empty() {
        return Err("give it a token: --token or RUNWELL_TOKEN (Settings > Connected apps)".into());
    }
    config.workdir = fs::canonicalize(&config.workdir).map_err(|e| format!("--workdir {}: {e}", config.workdir.display()))?;
    Ok(config)
}

fn hostname() -> String {
    let name: String = read_to_string(Path::new("/etc/hostname")).trim().chars().take(60).collect();
    if name.is_empty() { "runner".to_string() } else { name }
}

fn host_user() -> Option<String> {
    let id = |flag: &str| Command::new("id").arg(flag).output().ok().filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string());
    Some(format!("{}:{}", id("-u")?, id("-g")?))
}

fn read_to_string(path: &Path) -> String {
    let mut text = String::new();
    if let Ok(mut file) = fs::File::open(path) {
        let _ = file.read_to_string(&mut text);
    }
    text
}

fn tail(text: &str, max: usize) -> String {
    let text = text.trim();
    let count = text.chars().count();
    if count <= max { text.to_string() } else { format!("…{}", text.chars().skip(count - max).collect::<String>()) }
}

fn sleep_unless_stopped(seconds: u64, stop: &Stop) {
    for _ in 0..seconds {
        if stop.load(Ordering::SeqCst) > 0 {
            return;
        }
        thread::sleep(Duration::from_secs(1));
    }
}

fn log(message: &str) {
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    let (h, m, s) = ((now / 3600) % 24, (now / 60) % 60, now % 60);
    eprintln!("{h:02}:{m:02}:{s:02}Z {message}");
}
