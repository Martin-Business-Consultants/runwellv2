# Runwell for AI assistants

Anyone who uses Runwell can do it through their own assistant: Muse, Grok, Claude, ChatGPT,
Claude Code, or anything that speaks MCP or can run a command. Your team connects to all of
Runwell, with exactly their role; a client's contact connects to their portal, and sees and does
only what they can there.

## For your team

Runwell speaks MCP at `https://your-install/mcp`. Settings > Connected apps shows the address
and the ways in:

- **Claude, ChatGPT, and assistants with connectors**: add a custom connector with that URL. The
  assistant opens Runwell to ask you to approve it (OAuth), and refreshes its own access.
- **Muse, and assistants that build their own bridge**: describe the server to it (an MCP
  server over Streamable HTTP at that URL) and give it a personal token from Settings >
  Connected apps when it asks for a key.
- **Claude Code**: `claude mcp add --transport http runwell https://your-install/mcp`, then
  `/mcp` to sign in.
- **The command line** (and any assistant that runs commands):
  `curl -fsSL https://your-install/install/cli | sh`, then `runwell login`.

Signed in to more than one Runwell (two businesses, say)? `runwell login` again with the other's
address: the CLI keeps a sign-in per Runwell and sends each only to its own. `runwell installs`
lists them, `runwell use <host>` picks the default, and `--on <host>` on any command (or
`RUNWELL_URL`) uses another this once; a task's brief puts `--on` on its commands, so an agent
can't act on the wrong Runwell's task of the same number. With a Claude Code per business
(`CLAUDE_CONFIG_DIR`), `runwell agent setup --on <host>` in each ties it to its own Runwell.
`runwell logout [host]` signs out of one, `--all` of every one.

What the assistant does is recorded as your agent ("Ted's agent via Muse"), with your role
exactly. Anything that reaches a client (an email, showing
something in the portal) is previewed first and done only once you agree.

### Reviewing what it did

- **What it adds comes in through Intake** (in the nav, `g i`), beside clients' requests: a task
  an agent adds with nobody on it, or on no piece of work, waits there (Source › AI) until someone
  someone accepts it (`accept_task`, or several with `bulk_accept_tasks`) or declines it
  (`decline_task`, `bulk_decline_tasks`, with an optional `note` saying why, kept as an internal note: kept, Declined in the client's portal, nobody emailed). An
  agent that knows who and where can say so (`owner_id`, `work_ref`), and the task skips Intake.
- **Made by AI.** Tasks › Made by… › AI lists every task an agent added (`made_by=agents`, on the
  table and the board; `list_tasks` takes it too). Each one carries the AI mark after its title
  wherever it's listed, naming the agent, and the side panel says "Added by Ted's agent".
- **Work it finishes waits for you.** An agent takes a task only as far as in review; a person
  marks it done (Show… › In review, or the board's In review column).
- **AI activity** (linked from Intake) lists everything agents did: tasks added, changes, notes,
  closes, newest first. It opens on your own agent's; pick a teammate's or everyone's, an area and
  a period. Each row opens what it touched (a task in the side panel). Agents read it too
  (`agent_activity`). Each record's History says the same ("Ted's agent via Claude …"), and every
  call a connection made is under its Activity in Settings › Connected apps.

## For clients

A contact with portal access connects their own assistant to `https://your-install/portal/mcp`,
or from **Connected apps** in the portal:

- An assistant that signs in by itself sends them to the portal to approve it, after the usual
  emailed sign-in link.
- One that asks for a key (Muse does) gets a personal key made on that page.
- On the command line: `runwell login https://your-install --client`.

Their assistant can see their work and how far along it is, the tasks and documents shared with
them (a task whole, with the messages on it and which they haven't read), and their requests. It
can send a request (about a piece of work, with a date and files), reply on a task, put their
things in order of priority and change their own details. A request or a reply is previewed first
and sent only once they agree. It never sees anything of another client's, or anything internal.

## What makes it dependable

- **Names, not ids.** "Give the holiday hours job to Priya", "catch me up on the Spanish pages":
  tools take names where they take ids. When a name fits several records, the answer lists them
  (`ambiguous`) for the assistant to ask which.
- **Catching up.** `changes` answers what happened since the last look, with a cursor to pass
  back, so a morning routine hears each change once.
- **One-tap starts.** Prompts like plan my day, standup, go through requests, a weekly client update
  and catch me up; clients get where are things at and ask for something.
- **Records as context.** `runwell://works/WO-12`, `runwell://clients/Bloom` and the
  like can be attached to a conversation.
- **Safe retries.** A change sent with an idempotency key (the CLI adds one to every change)
  happens once, however often a flaky connection sends it.
- **Guard rails.** Each connection may make 120 calls a minute (`RUNWELL_AGENT_RATE_LIMIT`).
  Connected apps lists each one's recent calls; pause one to stop it at once, or disconnect it.
  An owner sees every connection, clients' included.
- **Clear errors.** Every error has a code (usage, not_found, ambiguous, auth, forbidden,
  refused, invalid, read_only, paused, rate_limited, failed) and a hint saying what to do.

## Checking it

`bin/rails agent:scenarios` plays a project manager's, an employee's and a client's requests
through the tools against your own records, inside a transaction that's rolled back, and says
which worked. `bin/rails agent:coverage` lists every staff action and its tool.
