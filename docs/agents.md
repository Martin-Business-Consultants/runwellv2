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

What the assistant does is recorded as your agent ("Ted's agent via Muse"), with your role
exactly. Anything that reaches a client (sending an agreement, emailing a link, showing
something in the portal) is previewed first and done only once you agree.

## For clients

A contact with portal access connects their own assistant to `https://your-install/portal/mcp`,
or from **Connected apps** in the portal:

- An assistant that signs in by itself sends them to the portal to approve it, after the usual
  emailed sign-in link.
- One that asks for a key (Muse does) gets a personal key made on that page.
- On the command line: `runwell login https://your-install --client`.

Their assistant can see their engagements (each agreement exactly as it was sent), the work and
documents shared with them, and their requests; it can send a request, and, for a contact who
can approve, decide on an agreement after showing it to them and taking their typed name. The
decision says it came through their assistant. Settings > Connected apps has the switch that
keeps agreement decisions to the portal and emailed links instead. It never sees anything of
another client's, or anything internal.

## What makes it dependable

- **Names, not ids.** "Give the holiday hours job to Priya", "catch me up on the Spanish pages":
  tools take names where they take ids. When a name fits several records, the answer lists them
  (`ambiguous`) for the assistant to ask which.
- **Catching up.** `changes` answers what happened since the last look, with a cursor to pass
  back, so a morning routine hears each change once.
- **One-tap starts.** Prompts like plan my day, standup, triage requests, a weekly client update
  and catch me up; clients get where are things at and ask for something.
- **Records as context.** `runwell://engagements/WO-12`, `runwell://clients/Bloom` and the
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
