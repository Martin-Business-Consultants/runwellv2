# runwell-runner

Claims work from a Runwell factory, runs an AI agent on it in a fresh container, and reports
back. One small static binary; the only thing it talks to is Runwell's MCP server.

## How a run goes

1. `claim_work` hands the runner the next queued piece of work (earliest due first) with a
   lease, the task for the agent, and the repositories with their clone commands.
2. The runner makes a directory for the run and starts a container from the agent image with
   it mounted at `/work`, running as your user. Inside, it clones the repositories onto the
   work's branch, then runs the agent with the task on stdin.
3. While the agent works, the runner renews the lease (`heartbeat_run`). If a person cancels
   the run in Runwell, the next heartbeat says so and the runner stops the container. It also
   stops the agent at the run's time limit.
4. The agent ends its reply with a JSON block (`outcome`, `summary`, `branch`,
   `pull_request_url`). The runner reads it, with the cost and tokens from Claude Code's JSON
   output, and calls `finish_run`. Success puts the work in review for a person; failure frees
   it for another attempt, or blocks it once the attempts are used up.

If the runner dies, its lease runs out and Runwell frees the work by itself.

## Build

```sh
cargo build --release                  # target/release/runwell-runner
docker build -t runwell-agent .        # the agent's container: Claude Code, git, gh
```

For a static Linux binary to copy onto servers:
`rustup target add x86_64-unknown-linux-musl && cargo build --release --target x86_64-unknown-linux-musl`.

## Run

```sh
export RUNWELL_URL=https://runwell.example
export RUNWELL_TOKEN=rw_…              # Settings > Connected apps, for an owner or manager
export ANTHROPIC_API_KEY=sk-ant-…      # or CLAUDE_CODE_OAUTH_TOKEN
export GH_TOKEN=github_pat_…           # push branches, open pull requests
runwell-runner --name build-1
```

Runs are recorded as the token's person's agent ("Ted's agent"). `--once` takes one piece of
work and exits (handy from cron or CI). `--help` lists everything.

Give `GH_TOKEN` the least it needs: a fine-grained token for the client repositories with
contents and pull requests read/write, and no admin. Protect `main` so an agent's work only
reaches it through a reviewed pull request.

`--agent` swaps the agent: any command that reads the task on stdin and ends its output with
the JSON block works. `--no-container` runs the agent directly on this machine, which gives it
everything your user can reach; keep that for trusted work on a machine set aside for it.
