# Runwell v2 — Project Guide

The core of project management, for a business or anything someone runs (a home, a wedding, a
trip): who we work for, what we run for them,
what is happening on it, what came in, and what needs a person now. No
money, no time tracking; see `docs/future_apps.md` for everything left out.

## Stack

- Rails 8.1, Ruby (see `.ruby-version`), SQLite, single tenant
- Prawn is bundled for plugins' PDFs (plugins load outside Bundler, so they use only the core's
  gems); the core itself makes none
- Hotwire (Turbo + Stimulus) over importmap and ERB views; plain CSS in
  `app/assets/stylesheets` served by Propshaft, no build step. Components are rune_ui (a gem
  shared with Botter, `../rune_ui`) plus Runwell's own pieces in `app/assets/stylesheets/runwell`
  (Frontend, below); behaviour (keys, boards, popups, pagination) is modelled on Fizzy (`../fizzy`)
- Search: ActiveSearch (`rails-active_search`) over SQLite FTS5, one polymorphic
  `:searchable` index (`config/search.rb`, `SearchableDocument`)
- ReActionView (https://reactionview.dev) compiles every `.html.erb` through
  Herb (`config/initializers/reactionview.rb`): validation overlays, debug mode
  and reactive template state
- Staff auth: Rails' generated authentication (`Session`, `User`). Sign-up only makes
  the first owner; everyone else joins by invitation. Clients never have passwords:
  portal sign-in is a signed, expiring link that works once, behind a button (`Portal::SessionsController`)
- Time zones: stored in UTC, shown in the install's zone (`Setting.zone`: Settings > Address, else
  `TIME_ZONE`, else Eastern; `ApplicationController` and `ApplicationJob` run inside it). A client may have its own (`Client#time_zone`, blank = ours); its
  portal (`Portal::BaseController`), plugins' client pages and emails run inside `client.in_time_zone`.
  Staff pages and agent input stay in the install's zone. A record read before the zone switched
  keeps the old zone, so client-facing templates call `.in_time_zone` on times they show
- Solid Queue for everything slow: mail, plugin changes, updates, search indexing, events
  to plugins, Check now and the test email (nothing waits on SMTP or GitHub in a request); letter_opener_web at `/letter_opener` in development. Production mail
  is any SMTP server from the environment (`SMTP_*`, see `docs/install.md`) or, when none, the one
  saved in Settings > Email (`Setting#smtp_settings`, password encrypted, `Runwell::MailDelivery`);
  the Outsend plugin routes it through Outsend instead, per message, with no restart. The sender is
  `Setting#mail_sender` (Settings > Email), falling back to `MAIL_FROM`, whichever way it goes out
- One install per deployment, its own data directory (`RUNWELL_DATA_DIR`: databases and files).
  Docker with Kamal by default (`config/deploy.yml`); a plain install is `bin/install` and
  `bin/update` (`docs/install.md`). `VERSION` is the core's version (`Runwell::VERSION`)
- Agents: an MCP server at `/mcp` (the `mcp` gem), OAuth 2.1 for connectors, bearer
  tokens, and the `runwell` CLI (`lib/cli/runwell`, served at `/install/cli`). See Agents

## Commands

| Command | Purpose |
| --- | --- |
| `bin/setup` | Gems, db:prepare, seeds |
| `bin/dev` | Rails (`Procfile.dev`); jobs run inside it in development (Active Job's async adapter), so development needs no `bin/jobs` (production can run it beside the web, `docs/install.md`) |
| `bin/rails test` | Minitest with fixtures |
| `bin/rubocop` | Lint (omakase) |
| `bundle exec herb lint app/views` | Lint templates (Herb) |
| `bin/rails import:unfold_general` | Move tasks off the "General" projects a v1 import made onto their clients (a dry run; `[apply]` does it) |
| `bin/rails search:reindex` | Rebuild the search index from every searchable record |
| `bin/rails agent:coverage` | Every staff action with its agent tool, or why it has none |
| `bin/rails agent:scenarios` | A manager's, an employee's and a client's requests played through the tools (rolled back) |
| `bin/rails db:seed:replant` | A sample business (a web / local search / ads studio). Logins `ted@brem.io` (owner), `sarah@` (manager), `marcus@`, `priya@`, `jordan@runwell.app` (members), all `password` |

## The five things the core answers

Two nouns carry the core, the same in the schema, the code, routes, tools, events and the UI:
**Work** (`Work`, `works`, `/work/P-3`: a project, work order or service run for a client; it was
"engagement" until 5.0) and **Task** (`Task`, `tasks`, `/tasks/42`: something to do, on a piece of
work or a client; it was "todo", and on screen "work", until 5.0). Settings > Names can still call
them something else on screen (`term(:work)`, `term(:task)`).

1. **Who we work for, and who can say yes** — `Client`, `Contact` (a user with the client role; `portal_access`,
   `can_approve`)
2. **What we run for them** — `Work` (ref like WO-12, P-3, S-4; `label` the key of its
   `WorkType`, below; shape fixed / recurring, and for recurring work a `cadence`), active from the start until closed
   (`Work#state`: active or closed). Its sections are `ScopeItem`s (the term `scope_item`,
   "Sections" by default; `work.scope_items`, positioned), each grouping tasks and showing
   how it's going (`delivery_state`); no price or estimate. A client marked `internal` is the
   business itself: its work is its own internal projects (`Work#internal?`). Nothing is
   "billable": everything is a project, work order or service. Agreements (a document the client
   signs) are a plugin's (`runwell-agreements`), not the core's
3. **What is happening** — `Task`, at `/tasks` (a lead owner and anyone else on it, status: planned, in progress, in review, blocked,
   done; due; table or kanban, opening on your own tasks, `owner: "me"`, with Anyone in the filter; agents finish into in review for a person to mark done). Made by… › AI (`made_by=agents`, `Task.made_by_agents`) lists what agents
   added, and `agent_made_tag` marks it wherever it's listed (`Task#made_by_agent?`, read through
   `User.agent_names`, once per request). A task
   sits on a piece of work (its client follows) or straight on a client (`tasks.client_id`;
   `work_id` optional), and nil client only for an email from an unmatched sender. A promise
   is a task with a due date: whoever it's assigned to owns it (there are no client-owned promises).
   `Event` (append-only, every write of consequence), `Note`
4. **What came in** — Intake (`/intake`, `IntakesController`, in the nav, `g i`, `list_intake`):
   every task that came in and hasn't been decided (`Task::Intake`, `intake?`). A task comes in
   (`intake_at`) when it's made without an owner or a piece of work: a client's request (portal,
   email, phone), a task an agent added, a task straight on a client; not a repeat's next one
   (`skips_intake`) nor an import. It stays until a decision, on a row, in the side panel's Intake
   bar (`intakes/_bar`) or in bulk (`Tasks::AcceptancesController`, `Tasks::DeclinesController`,
   `Bulk::Tasks::*`; tools `accept_task`, `decline_task`, `bulk_accept_tasks`, `bulk_decline_tasks`;
   both refuse a task not waiting, `Task::Refused`): `accept!` (someone owns it: the owner picked,
   else whoever's on it, else whoever accepts; `accepted_at`, `task.accepted`; a client who asked
   hears it's taken on) and `decline!` (with an optional line saying why, kept as an internal note
   on it, `note:`; kept, marked done with the reason Declined so nobody is emailed and it doesn't
   repeat; `declined_at`, `task.declined`; the portal shows it as Declined). Assigning or filing it
   meanwhile doesn't take it out (the side panel's Work picker, `work_id` on `update_task`; its
   client follows, a section of other work is dropped, `task.filed`); decided in the side panel,
   the panel closes. Every answer about a task carries `intake_streams` (its Intake row redrawn or
   removed, the panel's Intake bar redrawn), so Intake never needs a reload. Its Source column says
   where each came from (`intake_source_tag`; filtered by `Task.from_source`: clients, agents,
   team). A request is still a task nobody has
   taken on or started (`Task.requests`, what notifies and what the portal calls Waiting;
   `/requests` redirects to Intake). A task keeps who asked
   (`contact`, or `sender_name` / `sender_email`) and how (`source`: app, portal, email, phone…).
   Taking one on is assigning someone; one that isn't wanted is deleted. Portal contacts and
   emails create them (`task.requested`). Who hears what comes in is Intake's Schedule
   (`/intake/schedule`, `Intakes::ShiftsController`, `IntakeShift`, permission `manage_intake`, tools
   `list_intake_schedule`, `create_intake_shift`, `update_intake_shift`, `delete_intake_shift`): a
   line per person with its sources (clients, agents, team), days and either a window of the day
   (told as it comes in, `Notifier::IntakeNotifier`) or digest times (`IntakeMailer#digest`, everything
   waiting). With no lines, a client's request tells every owner and manager at once and nothing else
   notifies; with some, what nobody's window covers waits (`tasks.intake_notified_at` nil) for the next
   one to open (`IntakeShift.deliver`, `IntakeDeliveryJob`, every minute in production and as something
   comes in). Times are the install's zone
5. **What needs a human** — their own tasks, filtered on Tasks (`owner: "me"`, `due:` overdue,
   today or week, `status:` in review or blocked), and their notifications (mentions). The app
   opens on Tasks (`root`); the core has no home dashboard (the briefing, "Needs You", went in 5.0:
   one belongs in a plugin, with its own page and nav link). An agent that needs a person assigns
   them tasks or mentions them in a note; there is no separate question inbox.

A piece of work ends closed, as completed (delivered) or cancelled (`close_outcome`, shown by
`Work#state_label`; the state key stays "closed"), from Details or the bulk bar; reopening
(`reopen!`, `work.reopened`) puts it back. Setting a client dormant or former sunsets it
(`Client::Sunset`): its open work closes as cancelled and its open tasks are marked done, each with
the reason in its history, and the client records `client.sunset`; setting it active again reopens
nothing.

Commitments and the `Request` model were folded into tasks in 3.0, and `Question` removed; the 3.0
migrations moved their rows and history onto tasks (or, for a client's promise, its work or client).
Their tables, with the old sign-in tables (`identities`, `sign_in_providers`), were dropped in 5.17.
The `contacts` and `portal_sessions` tables from before contacts were users stay, unread
(`access_tokens`, `oauth_grants` and the agreement tables still name them by foreign key);
`Client#clear_legacy_rows!` clears a client's before it's deleted. `workspace_links` (5.40's workspace rail, taken out in 5.41) is
left, unread, for a later release to drop.

Agreements left the core in 3.0 for the Agreements plugin. Their tables (`agreement_versions`,
`approvals`, `approval_links`, and `scope_items.agreement_version_id`, `price_cents`,
`internal_estimate`, `settings.client_agent_approvals`) are left, unread, for the plugin to import
from and a later release to drop; the 3.0 migration put each scope item on its work and
re-pointed versions' and decisions' events, notes and documents at their work.

Rules the code enforces: events are immutable (the one exception: an owner erasing a closed
work for good, `Work#erase!`, typing its ref; the client keeps an `work.erased`
event); every event has a source.

## Conventions

- Rich models, skinny controllers, no service objects. Domain verbs are model
  methods (`close!`, `reopen!`, `move!`, `assign!`). A model is its core plus concerns named for
  what they do: shared ones in `app/models/concerns` (`Eventful`, `LiveRefreshes`,
  `RecordsCreation`, `BackgroundRun`…), a model's own under its name (`Task::Assignable`,
  `Setting::Mail`, `Setting::Appearance`…), as Fizzy splits `Card` and `User`
- A write of consequence records its event in the model, not the controller: creating a client,
  piece of work or task (`RecordsCreation`; a portal or email request is `task.requested`, marked
  with `requested: true`), a note added or deleted (`Note`), a status change (`Task`), a close
- Controllers find their records through `*Scoped` concerns (`TaskScoped`, `SubjectScoped` for
  what a note or document goes on) and say which record is on screen with `current_record`
- Patches to Rails and gems live in `lib/rails_ext`, one file each, required by
  `config/initializers/extensions.rb` (Fizzy's layout); none in initializers
- State is derived, never typed in (`Work#state`, `ScopeItem#delivery_state`)
- A state machine's rules live on its model, and every surface asks the model rather than keeping
  its own copy: its states in a constant (`Task::STATUSES`, `Client::STATUSES`, `Work::CLOSE_OUTCOMES`,
  `BackgroundRun::STATUSES`), which tool params, filters and pickers derive from; each move a verb
  that refuses a move the state doesn't allow (`Work#close!` raises `Work::Refused` when it's
  closed), with a predicate the page, the bulk bar and the controller ask first so they can say why
  (`closable?`, `reopenable?`); and one event per real change (`task.status`, `client.status`,
  `work.closed` / `work.reopened`), so history, `changes`, webhooks and plugins all see it. A rule
  the browser needs comes from the server (a Tasks list names the statuses it keeps,
  `data-task-list-keeps` from `Task::List#keeps`), never a JavaScript copy. The machines: a task's
  status (any to any; agents finish into in review), a piece of work (active, then closed as
  completed or cancelled, reopened), a client's status (any to any; dormant or former sunsets,
  `Client::Sunset`), a person (active, deactivated), a token (live, paused, revoked, expired), an
  invitation (pending, accepted, expired), a work type (active, archived; deleted only unused, merged only if not a system type: `deletable?`, `mergeable?`, `WorkType::Refused`), a webhook endpoint (on, switched off after
  `MAX_FAILURES`), an update or plugin change (running, then succeeded or failed, `BackgroundRun`),
  an export (queued, working, ready or failed), a notification (unread, read); and, derived, a
  section's delivery state and a task being a request
- Views are ERB templates rendering models directly; no serializers
- The core keeps no money, but plugins do, the same way: integer cents everywhere: columns, params, agent tools (`price_cents: "integer"`)
  and JSON (`*_cents` beside the formatted dollars). Dollars exist only on screen: a form
  field is `money_field form, :price_cents`, whose `money` Stimulus controller shows and
  takes dollars and submits whole cents; `money(cents)` formats for display
- Signed-out and client-facing pages use `layout "public"`; staff pages use
  the application layout
- A way in (sign in, a link, a code, a new password, sign-up, an invitation, the portal's sign in)
  also says `content_for :showcase, "team"` (or `"client"`): the public layout then splits, the form
  on the left with no card and, on a wide screen, `layouts/shared/_showcase` on the right (a panel
  mixed from the scheme's colour, `--color-link`, with frosted cards of made-up examples in the
  install's terms, and the theme toggle in its cut-out corner). Other public pages (consents,
  plugins' signing pages) keep the centred card
- Multi-line text is rich text: Lexxy (`<lexxy-editor>`, Fizzy's editor)
  writing HTML into the plain text column. In forms use
  `rich_text_field form, :body`; to display use `rich_text record.body`, which
  sanitizes and keeps older plain-text values readable. Never a `text_area`.
  Staff editors take files (Documents, below); client-facing editors are text only. Search indexes the plain text
  (`Searchable#to_search_document`)
- A snippet to read or copy (a command, a request body) is `code_block code, language: "bash"`
  (or `"json"`, `"ruby"`, any Prism name Lexxy carries), never a bare `<pre>`: Lexxy's
  highlighter colours it as it does code blocks in rich text (`runwell/components.css`)
- Every select is a runeui control, and every long one has a box to search its choices. The default
  form builder (`RunwellFormBuilder`) renders `form.select`, `time_zone_select`, `collection_select`
  and `grouped_collection_select` as Rails does, and `select_control` (`SelectHelper`) rebuilds that
  `<select>` as `ui :select` (a short list) or `ui :combobox, trigger: true` (more than
  `SEARCH_OVER` choices, `multiple`, or `search: true`: a button like a select's, the search box in
  its popup), so include_blank (a choice of its own, sent as ""), selected, disabled and optgroups
  behave as in a select; a `select_tag` goes in `select_control(…)`, and `combobox: false` keeps a
  plain `<select>`. The control is form-associated (it joins a form it sits outside of by `form:`)
  and its value comes from the server (`default-value`), so a morph keeps an unsaved pick. A pick
  fires `change` on the control, and the select's `data-action` stays on it, so save-on-change
  forms (`change->form#submit`) work. The builder's text fields are `ui :input`, `text_area`
  `ui :textarea`, `check_box` `ui :checkbox` (`native: true` or `role: "switch"` keeps a native
  one), and `form.ui :component, :attr` reaches any other runeui control. An index's filters are
  `ui :filter` (below)
- Every date is `date_input form, :due_on` (or `date_input_tag` without a form builder): `ui :date_picker`,
  a field to type a date into ("10/20/2026", "Oct 20") with a calendar in its popup, sending
  YYYY-MM-DD under the form's name, and fires `change` once per change (typed, picked or cleared).
  Its value comes from the server, so a morph keeps a pick. `t` picks today (the `date-keys`
  controller, the install's today); a date that isn't required has a button that clears it. Never
  a text field for a date, and no other date picker
- Never inline CSS: no `style` attributes and no `<style>` tags in views. All
  styling lives in `app/assets/stylesheets`. The one exception is email, which can't load
  stylesheets: `layouts/mailer.html.erb` carries its own `<style>` (phones and dark mode only): the logo or
  name, a card edged in the scheme's color (`Setting#brand_color`), and a footer. Every email is
  `MailerHelper`'s pieces, styled inline for Gmail and Outlook: `mail_heading`, paragraphs, at
  most one `mail_button` (with the address under it), `mail_quote`, `mail_small`, plus
  `content_for :preheader` (the inbox's preview line) and `:reason` (why this address got it,
  in the footer of both parts). Plugins' mailers use the same. Previews: `/rails/mailers`
- No N+1 queries: Prosopite scans every request in development (logged, and in `log/prosopite.log`)
  and test (it raises, so the test fails). Preload what a page or JSON view reads (`includes`); a
  loop that queries per record on purpose goes in `Prosopite.allow_stack_paths`
  (`config/initializers/prosopite.rb`). `PROSOPITE_RAISE=0 bin/rails test` logs them all at once
- People read a piece of work's title, never its ref: breadcrumbs, headings, lists, notices,
  notifications and the portal say "Spring landing page", not "P-19" or "P-19 Spring landing page".
  The ref stays what addresses it (`/work/P-19`, `to_param`), what agents name it by and what
  search still matches; and a delete confirms by typing the title
- Write for anyone running something: a business of any kind, a team, or a person managing a home,
  a wedding or a trip. Never "agency" or any one industry's jargon in what people or agents read;
  the core's nouns come from Settings > Names (`term`)
- Do not write tests. Don't add new ones or extend existing ones unless asked

## Frontend

Reach for these in order, and stop at the first that fits:

1. **ReActionView state** for UI state that stays on the page: anything that
   opens, closes, switches or reveals. Declare it in the template with
   `<%# herb:state (open: false) %>`, change it with `data-herb-toggle`,
   `data-herb-set`, `data-herb-reset`, `data-herb-increment` or
   `data-herb-decrement`, and read it with plain `<% if open %>` around plain markup, or
   `hidden="<%= !open %>"` around anything with Ruby output. See
   `layouts/shared/_confirm.html.erb`
2. **A Fizzy Stimulus controller** for behavior markup can't express (focus,
   hotkeys, submitting on change). Copy it from
   `../fizzy/app/javascript/controllers` with any helpers it imports. A
   controller that needs template state uses ReActionView's `useState(this)`
   instead of touching the DOM
3. **A new Stimulus controller** only when neither of the above fits

The core keeps only the JavaScript it uses itself. A controller added for a plugin belongs in that
plugin (`app/javascript/<key>/`, Plugin JavaScript in `docs/plugin-contract.md`); the `repeater`
controller and `bulk_copy` went in 3.0 for that reason.

Every state change must run in the browser, never wait on the server: reads in the shapes the
client evaluates (a bare state, `!`, `==` / `!=` a literal; `herb-state-valid-reads`), in
`<%# herb:slots client %>` templates. A branch holding Ruby output (a path, a form, a CSRF token)
makes every toggle re-run the whole controller action and page, so a form opened in place is
always rendered and only hidden: `<div hidden="<%= !open %>">` around it,
`hidden="<%= open %>"` on its trigger, and `aria-pressed="<%= tab == "task" %>"` for a pressed
choice, never a class picked by `if`. Its first field has `autofocus` (Turbo skips hidden ones on load), and the
wrapper carries `data-controller="state-focus" data-state-focus-state-value="open"`, which focuses
it when the state changes (the guide's `useState` pattern). Esc closes it, even from a field: its
Cancel is `data-keys="esc"`; a `<details>` form closes on its own and the `open` behavior
focuses its `autofocus` field.

Stay on the page you're working from; bring the rest to it. Every state still has a real URL, so
Back, refresh and links work, and there's no client-side router:

- **The side panel**: a task opens over the page in runeui's side panel (`ui :side_panel, params:
  %w[task peek]` in `layouts/shared/_side_panel`: a drawer down the right whose body is the
  `side_panel` frame, `layouts/shared/_side_panel_content` inside it), its state the page's own URL
  plus `?task=42`. runeui's `runeui--side-panel` controller opens and closes it, keeps the address
  (pushed to open, replaced to follow, Back to close when it was opened here) and shows a skeleton
  while it loads; Runwell's `side-panel` controller on `<body>` adds the links, `j` / `k`, fetching
  ahead and closing on a click outside. A link that opens a task is `side_panel_link_to task`,
  which keeps `task_path` as its href (Cmd-click still opens the task's page). The layout draws the
  panel open on a full load (the block of `ui :side_panel`); a request for the `side_panel` frame
  renders just it (`ApplicationController#render_side_panel`, `layouts/shared/_side_panel_frame`,
  skipping the page's action). Esc, ✕ (`data-action="side-panel#close"`, `data-keys="esc"`) or a
  click outside it closes it (a click on another task follows it instead, and dialogs, popovers,
  menus and toasts keep it open); Esc inside it closes an open popup first, then the panel. It
  follows `j` / `k` (`keyboard:select`; it leaves focus on the page as it opens, `initial_focus:
  "none"`), with the tasks above and below fetched ahead (as a hovered task's link is). It loads by
  setting its frame's `src` (no page visit runs under it); a refresh morph reloads the frame. Its
  contents opt out of runeui's morph guard (`data-morph="replace"` on `tasks/_panel` and the peeks),
  since they sit inside a `ui-*` element. Its fields save on change with `inline=panel`, answered
  by `tasks/update.turbo_stream.erb`, which redraws the task wherever it shows. The portal's sheet
  is the same component (`params: %w[task]`, `portal/tasks/_side_panel` for its frame)
- **Peek**: a client, a piece of work or a contact opens in the same panel (`?peek=Work:12`, one
  panel at a time; `<type>/_peek`, `ApplicationController#side_panel_peek`, `PEEKABLE`) from
  wherever it's linked: `peek_link_to record` keeps its page as the href. Table rows' names, a row's
  Edit (`row_actions … peek:`), a task's work, a client's contacts and the task panel's context all
  peek. It shows the title and fields in place (the same zones and `update.turbo_stream.erb` as the
  record's page; in the panel a field reads as its value, label beside it, and turns into its input
  when pointed at or focused, and `peek_header`'s `meta:` puts a glance on the header's row: a
  client's status), open tasks and notes, and Open to its page; plugins' slots stay on the page
- **Creating in a modal**: an index's New (`index_toolbar … new_modal: true`) and an in-page add
  (Add a contact) load the new page into the layout's `modal` frame; `new.html.erb` renders
  `layouts/shared/_modal` around its form (`modal: true`) when `turbo_frame_request_id == "modal"`.
  The form submits inside the frame, so a refused save comes back in the modal with what was typed.
  Saved, the action answers `from_modal?` with its `create.turbo_stream.erb` (the modal emptied, the
  new row added and marked `is-fresh`, a toast linking to it); a record whose next step is on its
  own page (new work) redirects, and the frame's `breaks-out` behavior visits that answer
- **Drafts**: every Lexxy editor and multi-field form keeps unsent typing in `localStorage` (the
  `draft` controller, `draft_data(key)` and `draft_notice`; `record_fields/main_card` does it for new
  and edit forms), restored with "Draft restored" and Discard, cleared when the save works. So
  leaving a form never asks "are you sure"
- **Undo for tasks**: removing a task in the browser (its row's trash or `d`, the bulk bar, its
  page) acts at once with no dialog and offers Undo in the toast for eight seconds: `remove_later!`
  (`RemovesLater`) records a `PendingRemoval` and `PendingRemovalJob` removes it when it comes due,
  unless Undo (`PendingRemovalsController`) deleted the row first. Agents and plain posts remove at
  once. Marking a task done offers Undo too (the status picker, `Task#undo_done!`). The toast's
  button is runeui's toast action (`undo_notice`: `{ title:, duration:, action: { label:, url:, method: } }`,
  which `turbo_stream_flash` and the flash both take).
  Clients and work keep their dialogs: their deletes cascade
- **Rows go in place**: a row's trash button sends `inline=row` (once the confirm dialog says yes); `remove_row` answers a stream
  removing `dom_id(record, :row)` (every row partial's `<tr>` id), and `refuse_in_place` says why
  where you are
- **Live**: models that people watch include `LiveRefreshes` and name what a change touches
  (`live_streams`: the record, what it sits on, `:tasks` / `:works` / `:clients`); pages
  subscribe with `turbo_stream_from`, and Turbo morphs them when someone else changes something
  (the tab that made the change ignores its own). Imports stay quiet. Notifications refresh the
  person's page (`turbo_stream_from Current.user, :notifications` in the layout)
- **Answers redraw every place, never ask where they came from** (Fizzy's way): a change is
  answered by a `.turbo_stream.erb` that replaces each place the record can show; a target the page
  lacks is skipped. A task's status has its own controller (`Tasks::StatusesController`,
  `PATCH /tasks/:id/status`, `tasks/statuses/update.turbo_stream.erb`). A Tasks list describes
  itself (`data-task-list`, `-state`, `-item` on the section or the Tasks table), the picker sends
  that with the change, and `Task::List` says whether the task still belongs there, so a task
  marked done leaves Open at once. Nothing reads `request.referer` to decide an answer.
  `turbo_stream_flash(notice:)` (`TurboFlash`) shows the toast; `AnswersInPlace` removes a row (`remove_row`) and checks a form's `inline` (`inline?`)
- **Waiting shows**: a submitting form's button dims (`form[aria-busy]`), and the progress bar
  shows after 200ms
- **Optimistic where the result is predictable**: the page changes on the click and is put back if
  the save fails (`picker_controller.js` is the pattern). A task typed into a quick add and a note
  from the composer show at once, dimmed, copied from a `<template>` the server renders
  (`tasks/_pending`, `notes/_pending`, the `pending` controller), never markup written in
  JavaScript; a row being deleted fades (`row-delete`), the rows a bulk action is changing dim
  (`bulk`), a clicked tab is current before its frame arrives (the `picks-current` behavior, the
  frame's old content dimmed on `aria-busy`), and a `submit_on_change` switch flips back if its save
  fails (`revert-on-failure`)
- **Installable**: staff pages link the manifest (`pwa/manifest.json.erb`, the install's name, icon
  and colour) and register the service worker (`pwa/service-worker.js.erb`, versioned by
  `Runwell::VERSION`), which caches nothing signed-in: only `public/offline.html` for a page that
  can't load. Mentions are pushed to each browser or installed app a person switched on (Settings >
  Your account, the `push` controller, `Settings::PushSubscriptionsController`, `browser_only`) by
  `PushNotificationJob` beside `NotificationMailer`, signed with the install's VAPID keys
  (`Setting::Push`, the private one encrypted); one the push service says is gone is deleted. The
  app's badge and the tab's title ("(3) Tasks | Lumin", the install's sender name after the page,
  `page_title_tag`, kept current by the `badge` controller from the tray's total) follow the unread count. The portal is left out
- **Losing the connection**: the `connection` controller on `<body>` shows a quiet line while the
  browser is offline or live updates are down (`layouts/shared/_connection_status`), refreshes the
  page in place once when they come back after a real gap (broadcasts sent meanwhile are lost), and
  keeps a form that got no answer as it is, marked unsaved (`form[data-unsaved]`), sending it again
  once back online; a save the server refused still reverts. A frame or stream answered with the
  sign-in page (marked `X-Runwell-Sign-In`) sends the page itself to sign in, and sign-in returns to
  it (`Authentication#request_authentication` remembers only page requests)
- **Messages are toasts**: notices and alerts are runeui's toasts, in its toaster (`ui :toaster`,
  once per layout in `layouts/shared/_feedback`, with `ui :confirm` and the flash as
  `flash_messages`), floating in the bottom right, never pushing the page; a notice goes by itself,
  an alert stays until closed. From a stream it's `turbo_stream_flash` (`turbo_stream.ui_toast`);
  a message may be a hash with an `action:` (a button that sends a request, or `href:` a page)

Page changes use the browser's own view transitions, no JavaScript: Turbo renders its visits
through them (`<meta name="view-transition" content="same-origin">` in `layouts/shared/_head`) and
full loads take `@view-transition` (`runwell.css`, which also keeps the nav still as its own
`view-transition-name` and turns them off for reduced motion). An element worth carrying across
pages gets a `view-transition-name` unique on the page; nothing calls `startViewTransition` for a
page change.

JavaScript that should follow elements as they come and go is a ReActionView behavior
(`app/javascript/behaviors`, one file per attribute, listed in `behaviors/index.js`), not a
controller or a document listener.

`<Async>` / `<Lazy>` (deferred content) re-run the controller action and render only their block,
which the server finds in the action's own template: they work only there, never in a partial or
a loop, and pay off only when the block is slow (measure; the History timeline isn't).

Shared pieces, so the same markup is never written twice (all helpers, so they work inside
`form_with`): a menu is `ui :menu` (one on the page that many buttons open, `data-runeui-open`,
as the task pickers do), or `popup_menu label:, title: do … end` (`PopupHelper`, Fizzy's popup,
left for plugins); an on/off switch is
`switch_field form, :attr, label:, hint:, submit_on_change:` (`ui :switch`, sending "0" when off;
with a hint, the settings row; without, the switch beside its label), or `ui :switch, name:` with
no form builder (`switch_tag { check_box_tag … }`, the old native one, stays for plugins); a
field with its label, hint and the record's errors is `form.ui :field, :attr, label:,
description: do … end` (`record_fields/*`); an empty list is
`ui :empty, description:, action:` (where its records come from; `layouts/shared/empty` is the
same under the name plugins render).
A list of the same partial is `render partial:, collection:, as:` (herb lint's
`actionview-prefer-collection-render`), not a loop.

Every question is asked in one dialog, runeui's (`ui :confirm`, in `layouts/shared/_feedback`):
the button that does the thing carries `data-turbo-confirm` (`confirm_data(title, description:,
button:)`, `ConfirmHelper`), and Turbo waits for the answer; Esc or Cancel puts focus back. Never
the browser's own `confirm()`, and never a dialog per record. A trash icon is
`render "layouts/shared/delete_dialog", name:, path:, message:` (`delete_button`). In a table row
it's `row_delete_button` instead (from `row_actions`), which sends `inline=row` so the row fades
and goes in place (`row-delete` controller). A destructive action on a record's own page (delete,
archive) is `render "layouts/shared/confirm", trigger:, title:, body:, button:, path:`
(`confirm_button`; `d` presses it), and the bulk bar's Delete is `bulk_delete`. Erasing a closed
piece of work asks for its title to be typed: `ui :alert_dialog, confirm_text:` (`works/_erase`).

Boards are runeui's board (`ui :board`, `ui :board_column`, `ui :board_card`): the Tasks board
(`tasks/board/_columns`, a `tasks/board/_column` per status, `TasksBoardHelper`) is the reference.
A card (`tasks/display/_preview`, `board-card-<id>`) is dragged between columns and up and down
one, or moved from the keys; runeui shows the move at once and posts it to the column's own
endpoint (`task_drop_url`: `Columns::Tasks::Drops::{Streams,Columns,Closures}Controller`, the card
named in the path as `__card__`) with `before` (the card it now sits before) for `Task#move!`,
whose answer replaces that column (`board-column-<status>`) with a morph; a refused move puts the
card back. Cards keep a manual order (`Task#board_position`, positioned per status; Done sorts by
date). Each column's first page is drawn with the board (`task_board_page`) and says its total
(`total:`); the rest load as it scrolls (`task_board_more`: a lazy frame at the list's end, which
`Tasks::ColumnsController` answers with the next page's cards in its place, `tasks/board/_more`).
Planned stays open; the doing columns and Done fold to strips from their titles, remembered per
browser (the board's id). A card's title opens it in the side panel (`side_panel_link_data`). A
column's own page (`tasks/columns/show`, its maximize button) is the same column as a grid. Column
dots take their status's colour (`task_column_tone`, `runwell/tasks.css`), never inline styles.

Staff pages are runeui's shell (`ui :app_shell`, inset, in the application layout): a left nav
(`layouts/shared/_sidenav`, with `_sidenav_brand` and `_sidenav_foot`; `ui :sidebar_group` and `ui :sidebar_item`; `runwell.css`) beside the page in an inset panel. The nav has the install at the top, then its
sections as the install arranges them (`NavLayout`, Settings > Sidebar, kept in `Setting#layouts["nav"]`:
named sections in order, or unnamed for no heading, holding the core's pages and plugins' together
in any order, and a Hidden tray; arranged like template mode, by dragging or the keys, with the
`nav-layout` controller, or the `arrange_sidebar` tool; `nav_sections` draws it, `sidenav_link_to`
marks the current one). Plugins have no section of their own: one switched on later joins the end
of the first section. Each person can still hide plugins for themselves (Settings > Your account >
Your menu, `User::NavPlugins`), and `g 1`… number the plugins shown, in order. At its foot the signed-in person, whose menu holds
their account, settings, light or dark, the shortcut sheet and sign out ("/" and `?` are keys
too). The panel opens with its bar (`layouts/shared/_panel_bar`): the nav's toggle and a breadcrumb
from `parent_page` and `@page_title` (`breadcrumb_items`, `ui :breadcrumb`). `[` collapses the nav
to icons (runeui's `runeui--sidebar` controller, remembered in a cookie so the server draws it that
way from the first paint; nothing of Runwell's handles the key), and below 768px the nav slides in
over the page. Every index shows its records as a table (there's no
cards view since 5.0), and has no heading: the nav marks the current section. The controller sets
`@view = index_view` ("table"; Tasks adds `extra: %w[board]`, read from `?view=`). The page starts with
`render "layouts/shared/index_toolbar", view: @view, new_text:, new_path:`: the page's
filters on the left (`ui :filter` pills, wrapped in `<% content_for :index_filters do %>` before
rendering the toolbar, which puts them in `ui :filter_bar`), and on the right the New button
(`new_link`, a `ui :button`), with the Table / Board toggle (`view_toggle`: `ui :toggle_group` as
links) where an index has a second view (Tasks). Then the table
(`render "layouts/shared/list_table"`, below: runeui's `ui :table`), whose
last cell per row is `render "layouts/shared/row_actions", name:, edit_path:, delete_path:` (pass nil for an
action the record doesn't allow: work delete only while it has no tasks). Every table can act on several rows at once: picking is runeui's (`ui :table, selectable: true` and a
`ui :select_cell` per row and, `all: true`, in the header: the `runeui--selection` controller does
select-all, the mixed header, shift-ranges and the count; `x` presses the checkbox of the row you're
on, `checkbox: { data: { keys: "x" } }`), and the page builds its bar with `bulk_bar` (`BulkHelper`,
on `ui :bulk_bar`: `bulk_menu` a `ui :menu`, `bulk_button`, `bulk_date` a `ui :date_picker` in a
`ui :popover`, `bulk_text`, and `delete:` `bulk_delete`) and hands it to the table (`bulk:`, with
`noun:` for "3 clients selected"). While rows are picked the bar takes the toolbar's row (CSS,
`runwell/components.css`). Each action is a small form of its own; the `bulk` controller on
`<main>` adds the picked ids as it's sent (`ids[]`), dims the picked rows while it runs and clears
the selection after,
each posting to a `Bulk::` controller that runs the record's own verb on each picked row with
`BulkAction#apply_to_each` (skipped ones named), with an agent tool beside it. Plugins' pages still
pick rows the old way until they move (the plugin contract: native checkboxes from
`bulk_select_all_header` / `bulk_select_cell` or their own `data-bulk-target="item"`, and the bar in
the toolbar through `content_for :index_bulk`), which the `bulk` controller keeps working. Lists
page with geared_pagination: the action wraps its records in `paginate` (HTML only; JSON for agents
stays whole), 13 rows a page, and the table shows which rows are showing and the pages under it
(`table_pagination`: `ui :pagination`). A list that loads its next page as you scroll instead
(plugins' tables, a maximized board column) is Fizzy's way (`PaginationHelper`, the `pagination`
controller): a table's `<tbody id="<%= pagination_frame_id_for(:name_rows, @page.number) %>">` ends with
`table_next_page_row :name_rows, @page, columns:` on a `<table>` carrying the pagination
controller in discard-frame mode. Mark each card or row `data-filter-target="item"` so "/"
filters it. The filter itself is one control at the foot of the nav
(`layouts/shared/nav_filter`): out of sight until "/" focuses it, and absent on pages with
nothing to filter. Pages never render their own. The filter controller lives on
`#global-container`. On a paginated list it reaches every page, not just the rows loaded: `paginate`
filters by `?q=` (`TextFilterable`: each model names the columns its list matches with
`filters_text_on`, joins included; each word typed must appear in one of them) and marks `#main`
`data-filter-remote`, so the filter also asks the server and swaps `#main`'s content for its
matches, the address keeping `q` (Back, refresh, sorting, quick filters and the next pages carry
it). The Tasks board's columns take `q` too (`TaskBoardScoped`). A new paginated model declares
`filters_text_on`.

A record's page, and its new and edit pages, are a `record-page` (`runwell/records.css`): a
header row across the top (`record_header id:, actions: do … end`, `RecordPagesHelper`: runeui's
`ui :page_header`, in a partial of its own such as `clients/_header`: the title, changed in place,
and a muted `record-header__line` under it, then the record's actions as outline `ui :button`s,
Copy for AI and the like, then the arrange button and the sidebar toggle `]`), then the working
column (`record-page__main`, 2/3: the description, tasks, the form) beside the sidebar
(`record-page__aside`, 1/3: Details as a `dl.details`, the smaller sections such as contacts and
plugin panels, notes or history, delete or archive). Both columns are stacks of runeui cards:
`record_card title, hint:, action:, footer:, id:, css: do … end` (`ui :card`, its title a heading,
its content stacked); an empty list in one is `ui :empty, size: :sm`. New pages use the sidebar for
what comes next (`record-steps`) and related records. Never a lone centered card for a form. A
record with several sections (clients, work, tasks, scope items) puts them in tabs in the working
column: `record_tab(key, label, count:)` plus `plugin_record_tabs(:client_panel)` (one tab per
plugin panel), `current_record_tab(tabs, default)`, and `render "layouts/shared/record_tabs"`
(runeui's `ui :tabs` as links, `record_tab_links`) inside `<turbo-frame id="record_tab"
target="_top">`. A tab is a `?tab=` link that only reloads the frame (the `picks-current` behavior
marks it current on the click); the first heading in a tab is hidden since the tab names it.
Plugins' hand-written `.card`, `.record-page__header` and `.tabs` markup still draws (compat). The sidebar keeps
Details, the few things always needed (contacts), History, and destructive actions. A piece of
work is the exception: its facts are one line under the title (`record-meta`, with
plugins' `:work_meta`) and its next step a muted line under that; its description opens from
an info button beside the title (`ui :dialog`, no Overview card); finishing it is Mark complete or
Cancel it in its sidebar, each asking in `ui :alert_dialog` with an optional note (`works/_close`;
`d` opens Mark complete); its Tasks tab shows the tasks by
section or, with the List / Board switch (`?task_view=board`, `tasks/_view_switch`), as the Tasks
board for everyone's tasks on it (`@board_filters`, which `task_board_filters` hands the columns and
drops); History is a tab, and the sidebar is its sections (`works/_sidebar`: `ui :tabs`,
Sections and General; `works/_scope`, where they're added, `data-morph="replace"` so a refresh
redraws a reordered list inside the tabs): all tasks, each section with done of total (moved to a
new place by its grip there too, dragged or ↑ ↓, through the same `ScopeItems::MovesController`),
and other tasks, each a `?item=` link that shows just that work in the Tasks tab, where its tasks are
added. In the Tasks tab each section (and other tasks) is an accordion (native `<details>`, not
`ui :accordion`, whose open state a morph would hand back to the server's list: the first open,
and any empty one, and the one a task was just added to; the `keep-open` behavior keeps whatever
someone opened through a morph), dragged by its grip to a new place (the core's
drag-and-drop, `ScopeItems::MovesController`), and ends in a quick add (`tasks/quick_add`): a
title and Enter adds it there, the section comes back in place with its filter and focus kept and
the field still focused for the next, and Esc empties it; not on Done, nor on closed work. A new
section is the + beside the tab's hint (there's no Add task under the list). A section's add action is one small outline button with the add icon after its list
(`record-add`), a `<details>` whose `<summary>` is a `ui-button`, when it opens a form; the one primary button on a page is its next
step. Up a level is `parent_page label, path`, called in the template: a `<link rel="up">` that
Esc follows and the panel bar's breadcrumb shows, never a Back button.

Guide people through the hierarchy rather than documenting it. A record page says what happens
next (`work_next_step` under the work's state). An empty list says where its records
come from and links there (`tasks/_blank`), since Tasks is added on the
work or client (or from anywhere with the quick action, `g t n`, which New task on the Tasks index opens too). Help (`settings/helps`: the overview, Connecting an MCP and Using with AI, nested under Help
in the Settings sidebar) uses `term()` for every name, and the `?` sheet links to it.

People show as their avatar, never their name: `person_tag user` (name as the tooltip and
for screen readers; `fallback: "Unassigned"` for nobody). Only a list of the people
themselves (Users) prints names beside the avatars. Who's on a task is Fizzy's
assignments (`Assignment`, `Task::Assignable`): `owner` is the lead and everyone on it, the lead
too, has an assignment (`task.owners`, lead first; `Task.assigned_to(user)` for "mine"). It changes
in place with `render "tasks/owner_picker", task:`, a menu where each click puts a person on or
takes them off (`Tasks::AssignmentsController`); the first on leads, and taking off the lead hands
it on. Setting `owner_id` directly replaces the lead and keeps the rest; `other_owner_ids` sets the
rest. Show them with `task_owners_tag task` (preload `assignments: :user`). A task's status
changes in place with `tasks/status_dot`, and its due date in a row with `tasks/due`. A row carries
only their buttons: the menus are on the page once (`task_picker_menus`: a `ui :menu` of the
statuses, a `ui :combobox` of the team with no trigger of its own, a `ui :popover` holding a
`ui :calendar` with Today and No date), each opened beside the button that names it
(`data-runeui-open`), and the `picker` controller takes the menu over for its task as it opens. The
side panel carries its own copy (`task_picker_menus(panel: true)`), for a page without task rows.
The pickers show a choice before the server answers: the avatars redraw from each person's avatar
template, a row a new status takes out of its list fades, and a save that fails outright is put
back. The clients table's status badge works the same way (`client_status_menu`).

Filters on an index page sit above the list, not inside the card: a row of
`ui :filter, param:, label:, value:, any: false, options:` in
`content_for :index_filters`, which the index toolbar shows in `ui :filter_bar`. Each is runeui's
filter pill ("Owner: Anyone"; `search: true` for a long list, which gets a box to search it) in a
GET form of its own that swaps one query param, carrying the page's others and dropping `page`, so
filters are bookmarkable and Back undoes the last one; the controller reads the params
(`works#index`) and passes what it settled on as `value:` (the pill is tinted only while the param
is in the address). `any: false` because Runwell's lists name their own "all" choice among the
options. `layouts/shared/quick_filter` is the same thing under the name plugins render. Don't drive a list with
ReActionView state: in 0.6 a list stops refetching after the first change.

Styling: components come from **rune_ui**, the UI kit Runwell shares with Botter
(`Martin-Business-Consultants/rune_ui` on GitHub, locked by revision; to work on it beside the
core, `bundle config local.rune_ui ../rune_ui`; its README lists every helper and class). A fix to
a component goes in the gem, so both apps get it. Runwell's own CSS is in `app/assets/stylesheets`, after rune's (which is all in
the `rune` layer, so Runwell's unlayered rules win), listed in order in `RUNWELL_STYLESHEETS`:
the theming contract (`_global`, `appearance`, `font-face`), `rune-theme` (points rune's tokens
at the palette), `runwell` (the shell: sidebar, page filter, settings layout, sign-in and portal
layouts), `runwell/components` (what every area shares: popups, the index toolbar and filters,
lists, the bulk bar, index cards, hint mode, form widgets) and one file per area
(`runwell/home`, `tasks`, `records`, `settings`, `public`). The styleguide is at `/ui` in
development. Build new markup with it:

- The brand's colour (`--accent`, Settings > Appearance) marks what's chosen, current or under the
  keys: `--brand-tint` / `--brand-tint-strong` (mixed from `--accent`, so they follow any scheme,
  light or dark) behind it and `--accent` on its icon (menus, comboboxes, the selected row, the
  current nav entry, search results), plus checkboxes and selected text. New highlight states use
  them rather than a grey layer
- Tokens are rune's: `--page`, `--panel`, `--layer-1..3`, `--text`, `--text-muted`,
  `--text-faint`, `--line`, `--line-strong`, `--hover`, `--accent`, `--accent-soft`, `--ok`,
  `--danger`, `--attention`; space `--s-1..6`; `--radius-*`; `--control-h`, `--control-h-sm`,
  `--row-h`; type `--text-xs`, `--text-meta`, `--text-ui` (the body, 13px), `--text-read`,
  `--text-title`, `--weight`, `--weight-strong`. `rune-theme.css` builds them from the theming
  tokens (`docs/theming.md`), so Appearance and custom CSS reach them. New CSS reads these, never
  `--color-*` or `--lch-*` directly (unless it needs a palette colour rune has no token for)
- Helpers spell the components (markup built in Ruby, so Herb can't mangle it): `button_link`,
  `action_button`, `submit_button`, `icon_button`, `button_classes` (for `link_to`, `button_to`,
  `form.button`; variants `:primary`, `:secondary`, `:ghost`, `:danger`, size `:sm`), `badge`
  (`ui_status_badge` / `status_tag` for a Runwell status, toned by `STATUS_TONES`), `card`,
  `list_row`, `field`, `empty_state`, `menu` / `popover_menu` with `menu_link`, `menu_button`,
  `menu_label`, `menu_divider`, `dialog` / `sheet` / `confirm_dialog`, `tabs`, `callout`,
  `avatar` / `avatar_stack`, `settings_group` / `setting_row`, `switch`, `segmented`,
  `copy_button`, `progress_bar`. `icon_tag name` draws one of the icons
  `config/initializers/rune_ui.rb` registers (rune-style inline SVG); an unknown name draws a dot
- Classes where markup is written by hand: `btn btn--*`, `icon-button`, `pill` (a filter or
  picker's trigger), `card` (`__head`, `__title`, `__hint`, `__action`, `__content`, `__footer`;
  `--flush`, `--sm`), `list-row` (`__media`, `__content`, `__title`, `__desc`, `__actions`),
  `field` / `field__label` / `field__hint` / `field-row`, `badge`, `count`, `tabs` / `tabs__tab`
  (`--pills`, `--icons`), `alert`, `table` in a `table-wrap`, `dl.details`, `empty`, `stack`,
  `grid-2`, `button-row`, `separator`, `<kbd>`, `muted`, `faint`, `small`, `visually-hidden`.
  Bare inputs, selects and textareas need no class; every `<form>` is a flex column with a gap
  (`form.button_to` is inline), so an inline form gets its own layout class
- Menus and pickers are runeui's (`ui :menu`, `ui :combobox`, `ui :popover`, `ui :select`). Fizzy's
  popup (`<dialog class="popup">`, `popup_menu`, the `dialog` controller) is left for plugins, and
  the `dialog` controller for the notifications tray and the modals
- Native elements over JavaScript: `<dialog>` (the `dialog` controller's modals), runeui's
  `ui :dialog`, `ui :popover` and `ui :menu`, `<details>`, real
  checkboxes and radios. CSS uses descendant or class selectors, not child ones: in development
  ReActionView wraps every ERB output in a `display: contents` span
- Index tables are `layouts/shared/_list_table` (runeui's `ui :table`, `runwell/components.css`
  section 3): describe the columns with `ui_column(key, label, sort:, align:, hideable:, grow:)`
  and pass a row partial (`clients/_row`: `ui :select_cell`, then `<td data-column="key">` per
  column in order, then `layouts/shared/row_actions`). The table sizes itself, as shadcn's does:
  every column is as wide as what it holds, on one line; the column that identifies the row
  (`hideable: false`, or `grow: true` where that isn't it) takes the leftover width and cuts a long
  name short, its cells marked `data-grow`; a column of free text is capped with `data-truncate`
  (a title carries the whole value; `--ui-table-truncate` sets the cap); and a window too narrow
  for the columns scrolls the table sideways inside its box. No widths are measured or set. Order
  follows meaning (the identifier, what describes it, then state), and alignment the data (text and
  pills left, numbers `data-align="end"`). It brings sortable headers (`ui :sort_header`, writing
  the `sort` and `direction` params `TableSorting` reads), the checkbox column and bulk bar
  (above), a Columns menu in the header's corner that hides columns (`ui :columns_menu`, runeui's
  `runeui--columns` controller, per browser) and `table_pagination`. What every row shares goes
  in `row_locals:` so it's read once (Prosopite). A plain `.table` (settings lists, the portal,
  plugins) keeps the old convention: its first column (or `.table__grow`) grows
- An area's own pieces are BEM classes in that area's stylesheet. Space with `gap`, never
  sibling margins; no coloured left borders (states are tints, weight, dots and badges)

ReActionView rules:

- Every partial declares strict locals on its first line:
  `<%# locals: (client:) %>`, or `<%# locals: () %>` when it takes none.
  Render partials by full path (`render "clients/form"`,
  `render partial: "clients/client", collection: @clients`)
- A template with state names its rendering mode above the state: `<%# herb:slots client %>`,
  with forms hidden rather than branched (above). `<%# herb:slots server %>` only where a state
  change truly needs Ruby
- Key every loop: put `<%# herb:key record.id %>` on the line before each
  row. Without it a list that re-renders for a state change (a filter)
  keeps its old rows
- Don't put a condition after a render (`<%= render "x" unless done? %>`).
  ReActionView then escapes the partial as text. Wrap it in
  `<% unless done? %> … <% end %>`
- Turbo morphs a page that redirects back to itself, and ReActionView keeps
  its client state through the morph. A form inside a revealed state branch,
  or one whose result adds a new stateful partial, submits with
  `data: { turbo_action: "advance" }` so the page renders fresh
- Don't pick between a value and markup with `||` in one output tag
  (`<%= note.presence || tag.span("None") %>`): it rendered the fallback even with a note.
  Write `<% if note.present? %> … <% else %> … <% end %>`
- Don't mix a Ruby condition and a state read in one `if`/`elsif` chain
  (`if work.closed? … elsif starting`): the state change is
  never sent. Nest the state `if` inside the Ruby one
- State in attributes is reactive: `hidden="<%= !open %>"` (dropped while false),
  `aria-pressed="<%= tab == "task" %>"` and `<% if open %>hidden<% end %>` update in the browser;
  `class="<%= "x" if tab == "task" %>"` updates too, but only by asking the server. Never render a
  partial with state more than once on a page: ReActionView 0.6 sends the server only the first
  copy's state (`steering()` keys by file), so the others' toggles do nothing
  (`settings/plugins/_plugin` shows its switch by
  CSS `:has(:checked)` instead). For a per-row or inline "add / resolve" form, use a native
  `<details>` with a button-styled `<summary>`, which the morph after submit
  closes again (`tasks/_add`)
- Several forms for the same model on one page take
  `form_with …, namespace: dom_id(record)` so field ids stay unique
- Default optional locals to `nil` (`<%# locals: (icon: nil) %>`) and apply
  the real default in the body (`icon || "trash"`). Herb 0.11 prints any
  other default value as text at the top of the partial
- Don't render partials inside a `form_with` block. ReActionView 0.6 fails
  when it re-renders one for a state change. Render them before or after the
  form
- Keep markup valid (no `<div>` inside `<p>`, every tag closed). Herb shows
  errors as an overlay in development and raises in test
- Speed: after every render ReActionView sends the page's slot dependency map, which Herb 0.11
  rebuilt from the templates each time (half of a page's render). `lib/rails_ext/herb_slot_envelope_cache.rb`
  keeps each page's map until a view changes, beside its cache of Herb's per-file analysis
  (`herb_analysis_cache.rb`). Rich text renders once per distinct HTML (`RichTextHelper::RICH_TEXT_CACHE`,
  in memory). A row's status, owner and due pickers are buttons: their menus are on the page once
  (`task_picker_menus`, at the foot through `page_template`), never one per row
- Reactive features are experimental in 0.6. When something breaks, check the
  response of the `application/vnd.herb.slots+json` request the page makes
- Don't pass an interpolated string to `turbo_frame_tag`
  (`turbo_frame_tag "#{status}_cards"`): Herb treats it as a record and calls
  `to_key`. Write `<turbo-frame id="<%= status %>_cards">` instead
- Don't build a helper attribute with string interpolation
  (`link_to path, data: { action: "keydown.#{key}->form#submit" }`).
  Herb 0.11 writes that value unquoted, and the `>` in `->` closes the tag.
  Write the element as HTML with a quoted attribute instead
  (`data-action="keydown.<%= key %>->form#submit"`), as in
  `layouts/shared/_nav_filter.html.erb`
- Herb compiles `stylesheet_link_tag` into a single `<link>`, which skips
  Propshaft's `:app` expansion. The layout calls `app_stylesheet_tags`
  instead

## Search

- A model becomes searchable by including `Searchable` and defining
  `search_title` and `search_content` (plus `search_client_id` when the
  client isn't `client_id`). Put these public methods above `private`.
  Indexing runs in a job after each save (ActiveSearch's `ReindexJob`), so a new record shows
  a moment later; `Searchable.reindex_all` rebuilds it inline (the rake task, an import, seeds)
- Add the model to `Searchable::MODELS` and to `search_result_path` in
  `SearchesHelper`, then run `bin/rails search:reindex`
- `Search.new(terms).results` cleans the terms and returns records ranked by
  relevance, with `record.hit.highlight(:title)` and `(:content)` HTML-safe. It's fuzzy: exact
  matches first, then words starting with what was typed or a typo or two from it, taken from the
  index's vocabulary (`Search::Vocabulary`, fts5vocab). Agent name resolution passes `fuzzy: false`
- Results are grouped in a fixed order: clients, work, tasks, then people (the team, by name or
  email, `Search#people`, a direct lookup since users aren't indexed), then the rest
  (`SearchesHelper::SEARCH_PRIORITY`, `search_result_groups`)
- Search is runeui's command palette (`layouts/shared/_search`: `ui :command, dialog: true,
  src: search_path, min: 2`), in the application layout's footer for signed-in staff, opened by
  `s` (its out-of-sight button) or ⌘K (the palette's own). From two characters it asks /search as
  you type; `searches#show` answers a request carrying `Runeui-Command` with the palette's items
  (`searches/_palette`, `search_palette_items`: each result a link, a task's opening the side
  panel, anything else its page, then "See all results" to /search). Arrows and Enter pick, Esc
  clears the box and then closes it. The /search page is every result for a query, its field
  following what's typed (`form#debouncedSubmit` into the `search_results` frame, the address keeping `q`)

## Keyboard shortcuts

Vim style, and everything reachable without a mouse. One Stimulus controller on `<body>`
(`keyboard_controller`) handles every key; nothing else listens for letters. Keys act outside
inputs and open dialogs; `⌘/Ctrl+Enter` saves from anywhere in a form. The `?` sheet
(`layouts/shared/_shortcuts`, listed in `_shortcut_list`) is the
one place they are documented for people: add a new key there.

| Key | Action |
| --- | --- |
| `j` `k`, `gg` `G` | Move through the page's items (every `data-filter-target="item"`), first and last |
| `x` | Pick the table row you're on, for the bulk bar |
| `Enter` `o` | Open the item you're on |
| `e` `d` | Edit, or delete / archive / close (asks first; a task goes at once, with Undo): the item you're on, else the record on screen |
| `Esc` | Close a popup or dialog (runeui's handle it themselves), then drop the selection, then up a level (`parent_page`); in a form opened in place, cancel it |
| `g` + `c w t b u i n s` | Clients, work, tasks, board, users, intake, notifications, settings; `g 1`… plugin pages |
| `n` `v` `/` | New record, next view (Tasks: table / board), focus the page filter |
| `s` or `⌘K`, `a`, `?` | Search (the palette), quick actions (the + popover), the shortcut sheet |
| `i` | Ask AI (the AI plugin) |
| `g t n` | Add a task (the quick action) to a piece of work or client picked in it, the one on screen to start; `g t` waits a moment for the `n`, vim style |
| `.` | Hint mode on or off |
| Board: `h` `l` `j` `k`, `H` `L`, `J` `K` | Cards across and down the columns, move the card a column, or down / up its column (handed to runeui's board as arrows and Shift+arrows; the card you land on is selected, so the side panel follows) |

Moving with the keys fetches ahead: the row `j` / `k` lands on has its page (the plain link Enter
follows) fetched, and `g` fetches the pages its chords reach, once per page
(`helpers/page_prefetch`, handed to the visit through `turbo:before-fetch-request`, as Turbo and the
side panel do); a task's link leaves it to the side panel. Back or Forward to a list picks the row
you were on again (kept per address in `sessionStorage`). The sidenav keeps its scroll position from
page to page (runeui's sidebar controller), and the modal shows a placeholder for a New form that
takes more than 150ms (`loading-placeholder`, `layouts/shared/_modal_placeholder`).

Declare a key on the element it acts on: `data-keys="e"` clicks it, `data-keys-focus` focuses
it instead, `data-keys-anywhere` works while the element is out of sight (in a closed menu), `data-keys="g c"` is a chord, `data-keys="s, mod+k"` lists alternatives (`mod` is
⌘ on a Mac, Ctrl elsewhere). A key declared inside an item fires for the selected item only
(`row_actions` marks edit `e` and delete `d`); one outside any item is the page's. Show the
key on the button with `<kbd class="hide-on-touch">` (or `ui :kbd`).

Keys typed into runeui's controls stay theirs: the keyboard controller ignores a key another
handler marked handled (`defaultPrevented`), one typed in a field or editor, and any key while a
dialog, sheet, palette or popup is open or holds focus (`OVERLAY`: runeui's dialogs, menus,
popovers, selects, comboboxes, date pickers and `ui-command`), so Esc closes the popup and only the
next Esc drops the selection or goes up a level.

The `?` sheet is runeui's `ui :dialog` (`#shortcuts`, keys as `ui :kbd`), opened by its button in
the nav's foot (`data-keys="?"`, which the account menu's Keyboard shortcuts presses too), with hint
mode's switch at its foot (`#hints-switch`, `change->keyboard#setHints`, kept in step by the
controller).

Hint mode (`.`, or the switch in the `?` sheet) teaches the keys in place: the keyboard controller
copies each `data-keys` into `data-key-hint` (the first alternative, `mod` as ⌘ or Ctrl) and
`runwell/components.css` draws it as a keycap over the control, never moving anything; keys inside an item show
only on the row you're on, and controls that already show a `<kbd>` get none.
`layouts/shared/_hint_legend` lists the keys with no control (j/k, Enter, /, s, a, Esc, ?, as
`ui :kbd`). It's
remembered per browser (localStorage `keyHints`), off by default, and hidden on touch devices.
A new `data-keys` gets its hint for free. A new index page's "Add a …" button
renders `render "layouts/shared/new_button", text: "Add a client", path: new_client_path`.

## Mentions and notifications

Fizzy's, wholesale. Staff editors take `rich_text_field form, :body, staff: true`,
which adds the `<lexxy-prompt trigger="@">` fed by `prompts/users`. A mention is an
Action Text attachment (`application/vnd.actiontext.mention`) holding the user's sgid,
stored in the HTML column. A model with rich text includes `Mentions` and names its
columns (`mentionable_fields :body`); after save it scans them and creates a `Mention`
per person, which is `Notifiable`: `Notifier.for` picks `Notifier::MentionNotifier`,
which skips self-mentions and creates a `Notification`. Two more things notify the same way: a
client's reply on a task and a request from outside (Clients and the portal); a notification says
what it is through its source (`notification_title`, `notification_excerpt`, `notifiable_target`),
so the tray, the email and the push need nothing per kind. Notifications show in the
tray (`notifications/_tray`), which the bell at the right of the panel bar opens (`g n`), and on `/notifications`, and are emailed
(`NotificationMailer`). Opening one reads it and redirects to its record
(`notifications#show`). Client-facing editors never get the prompt.



## Documents

Files live in Active Storage (`storage/` locally). Two places:

- Inline in rich text: staff editors (`rich_text_field form, :body, staff: true`) take
  dropped, pasted or uploaded files through Lexxy's direct uploads, and `rich_text`
  renders them with the `active_storage/blobs/_blob` partials (styled by Lexxy's content CSS). Client-facing editors
  stay text only (`attachments="false"`)
- A Documents section (`render "documents/section", subject:`) on clients, work,
  scope items, tasks and requests: a `Document` per file (`Documentable`), with who
  uploaded it and a `client_visible` switch. Files are added from the quick action tray (Document), whose
  modal holds the dashed drop target (`document_drop_target`, `.upload-drop`). The portal lists only
  client-visible files (`Work#client_documents`)

## Plugins

The core has no money or time; plugins add them. A plugin is a Rails engine in a public GitHub
repository of its own, never in this one: the fourteen Runwell publishes are
`Martin-Business-Consultants/runwell-<name>` (`config/plugins.yml`). It is installed onto the
server, like a WordPress plugin: an install starts with none, and the only way one arrives is its
GitHub repository (owner/repo) in Settings > Plugins, which downloads the repository's latest release
into `RUNWELL_DATA_DIR/plugins/<name>` and restarts (`PluginChange`, `Runwell::Restart`), and
`config/installed_plugins.rb` loads it at boot, outside Bundler, so it can use only the core's
gems. Its migrations run after the core's on `db:migrate` / `db:prepare` (`plugins:migrate`), its
tables stay out of `db/schema.rb`, and its stylesheets and JavaScript (`app/javascript/<key>/`, pinned
by `config/importmap_plugins.rb`, its controllers registered as `<key>--name`) compile as production
boots. Each plugin
updates only when someone presses its Update button (`PluginRelease`, checked nightly); Remove
deletes its code and keeps its tables. An install whose plugin is on but missing puts it back
on boot (`PluginRestoreJob`). From the shell: `plugins:install[owner/repo or key]`,
`plugins:update[key]`, `plugins:remove[key]`, `plugins:list`, and `plugins:link[../path]` to work
on one (`docs/plugins.md`). Tests never load plugins. A plugin owns its tables (prefixed with its
key, e.g. `time_tracking_entries`), points at core records by id, and never changes core tables.
The core never names a plugin; remove it and the app runs as before.

**`docs/plugin-contract.md` is the contract**: every extension point (`lib/runwell/plugins.rb`:
manifest, slots and their locals, nav, home, quick actions, permissions, portal, settings pages,
nightly tasks, stylesheets, agent briefs and workflows), the model load hooks, the event kinds
published as `"event.runwell"` (from `EventPublishJob`, so subscribers read the actor from the
event), the helpers and partials a plugin may use, and the version each arrived in. Changing or
adding one means updating that page in the same commit (a new one says `Since` the next
release); removing or changing a stable one waits for a major version. Plugins are off until the
owner switches them on, whatever their manifest says (`Setting#plugin_states`); the core renders only what's registered by
plugins that are on, and a plugin's controllers and subscribers check
`Runwell::Plugins.enabled?(key)`. A settings page nests under Plugins with
`render "settings/header", current: key`, and keeps keys in `encrypts` columns shown with
`secret_field`. A plugin with several pages lists them in a sidebar beside the page, as Settings
does: `section_nav "Name" do … end` with `section_nav_heading` and `section_nav_link`
(`SectionNavHelper`, placed by the application layout), never a row of buttons.

Register in the engine's `config.to_prepare`; add routes to the app's route set from an
initializer (`app.routes.append { scope "time", module: "time_tracking", as: "time_tracking" … }`)
rather than mounting an isolated engine, so the core layout's helpers work on plugin pages.
Migrations need nothing: the core runs each installed plugin's `db/migrate`. Changes to an engine's `engine.rb`
(registrations, initializers) need a server restart; they aren't reloaded. A new plugin starts from
`Martin-Business-Consultants/runwell-plugin-template` (a working example of the contract, its own
AGENTS.md, `bin/rename`). The plugins Runwell publishes, and which is the reference for what, are
described in `docs/plugins.md`.

## Quick actions

The + at the right of the panel bar (`A`, `quick_actions/_tray`) opens a runeui `ui :popover`
below it (`#quick-actions`). At its top is the record picker (`quick_actions/_record_picker`: a
`ui :combobox, trigger: true` searching the server, `src:` `quick_action_records_path`, which
answers JSON by kind, `quick_action_record_items`) set to the record on screen
(`current_record`) and able to find any other; below it, one entry per action: Note,
Document and Task in the core (`g t n` opens the task form straight away, on a piece of work or a client), plus any a plugin registers
(`Runwell::Plugins.quick_action key, label:, icon:, partial:, types:, title:, context:`). The
entries submit one GET form with the picked record, and the action's form opens in a modal
(`quick_actions#new`, loaded into the `quick_action` frame) with the same picker. Documents
and time are added only here; notes also have a composer at the top of every Notes section
(`notes/_section`: the Lexxy editor, kind, source), posting `record` to the same `notes#create`.
The picker writes `record` ("Client:12") into the form through the `form` attribute; the
receiving controller reads it with `QuickAction.locate(params[:record], types)`. Forms post
with `data-turbo-frame="_top"` so the page redirects back as usual. Its button is a round + just left of the notification
bell, at the right of the panel bar; `A` clicks it.

## Requests by email

Clients email requests rather than signing in (Action Mailbox; `docs/install.md` has the setup).
An inbound service forwards the address in Settings > Email
(`Setting#requests_email`): the server's `INBOUND_EMAIL_INGRESS` / `RAILS_INBOUND_EMAIL_PASSWORD`, or else
the install's own `Setting.inbound_ingress` / `inbound_password` (Settings > Email, or a plugin such as
Cloudflare via `Setting#receive_mail_through!`; `lib/rails_ext/action_mailbox_settings_ingress.rb` reads them
per request, no restart). `ApplicationMailbox` routes everything to `RequestsMailbox`: each message
becomes a request, tasks nobody has taken on (`source` "email"): the subject its title, the message
its description (`Task::EmailBody` cuts quoted mail and signatures, preferring the text part),
attachments its documents (internal until shared), and the sender matched to a contact (and so a
client), or left with no client until someone picks one. A known contact gets
`RequestMailer#received`, a short acknowledgement with no reply address of its own: anything new
they send is a request of its own. Automatic replies and our own mail are dropped.

## Clients and the portal

Someone at a client is a user with the client role (`User::Role::CLIENT`), and `Contact` is that
slice of users (`class Contact < User`, a default scope; `Contact.polymorphic_name` keeps "Contact"
in search and events). They show in Users beside the team (Who…: everyone, the team, clients'
people), open on their contact page, have no permissions and no password (a random one), and never
reach a staff surface: `User.people` (pickers, mentions, sign-in) is the team only, password and
link sign-in refuse them, and a `Session`, `AccessToken` or `OauthGrant` reads `user` for staff
and `contact` for a client's person off the same `user_id` (`HeldByPerson`). Their job title is
`title` (`role` is the client role); `email` and `archived_at` alias `email_address` and
`deactivated_at`. Folded in by 5.1 (`users.legacy_contact_id` keeps each old contact id for
plugins). Two switches per contact:
`portal_access` (sign in by emailed link, see the client's shared tasks and documents, send
requests; Invite to the portal on their page emails what it is with a link good for a week,
`Contact#invite_to_portal!`, `contact.invited`, and Sign out everywhere ends their sessions) and `can_approve` (may say yes for their company, for a plugin such as Agreements or Approvals, which
puts a shared task to the client for a yes in its side sheet, the `:portal_task` slot). `Contact#portal?` is checked on every
portal request, so switching access off or archiving a contact signs them out at once. What
a client sees is decided per record (`client_visible` on tasks and documents); there are no
client roles. A contact may also be limited to some of the client's work (`portal_limited`,
`ContactWork`, set in the Portal card on their page or with `set_contact_portal_scope`): they then
see only those pieces of work, the tasks and files on them, and anything they asked for
themselves. Every portal page, tool and email reads what its contact sees through
`Contact::PortalScope` (`portal_works`, `portal_tasks`, `portal_documents`, `sees?`), never
`client.works` or `client.tasks` directly, and `Notice` tells nobody about what they can't see. A
new portal read goes through it. Staff see it for themselves with View as on a contact's page
(`Contacts::PreviewsController`, `contact.previewed`): the portal as that contact, read-only (a
signed `portal_preview` cookie beside the staff session; `Current.preview_contact`,
`Portal::BaseController#refuse_writes_while_previewing`), with a bar to stop. A portal controller
that writes needs nothing for it: any non-GET is refused while previewing. While previewing, an
owner can also arrange the portal's page for a piece of work (template mode, the `portal_work`
layout: its cards, any of which can be hidden; by default the tasks fill the page, grouped by
section in the client's order, the sections down the side, and the overview and details hidden; a
client never sees the controls). A shared task
opens in the same side sheet as staff pages (the `side-panel` controller on the portal's
`<body>`, `?task=`, `Portal::BaseController#render_portal_side_panel`, `portal/tasks/_panel`),
read-only and limited to the client's client-visible tasks, its lower half the task's discussion
with the client: notes shared on it (`Note#client_visible`, `Note.discussion`), which the client
answers there (`Portal::Tasks::NotesController`, `portal_reply_on_task`) and staff send with Send to
client in the task's notes (`Tasks::DiscussionsController`, `reply_to_client`, which confirms);
every other note stays internal. The discussion goes both ways by itself: the team's note is emailed
to the client's people on the task (`PortalMailer#reply`, to `Task#discussion_contacts`: whoever
asked and anyone who wrote on it, else everyone there with the portal), and a client's reply
notifies whoever is on the task (`Notifier::ClientReplyNotifier`, `Task#team_watchers`), as a
request from outside notifies owners and managers (`Notifier::RequestNotifier`,
`User.request_watchers`), or whoever Intake's Schedule says. A task holding a message a contact hasn't read is marked wherever it's
listed and counted on the nav (`DiscussionRead`, `Task.unread_discussion_ids`, read when its sheet
opens), and something a contact asked for being marked done emails them a minute later, unless it
was undone (`PortalMailer#done`), as does someone taking it on (`#taken_on`, the first person put on
it); files the team shares are emailed too, those shared together as one (`SharedDocumentsJob`,
`PortalMailer#documents`; not the client's own uploads). A contact turns these emails off in Your
account (`portal_emails`). Who hears is decided in one place, `Notice`: the core says who usually
would and everyone who could, and a plugin may choose among them per client
(`Runwell::Plugins.notices`; the Client dashboard plugin's tab on each client), never reaching
anyone outside `everyone`. A new notice to a client or the team goes through it. The portal's pages refresh live (`turbo_stream_from client`; the cable takes a
portal session). A client never reads the team's statuses: `Task#client_status`
(`Task::CLIENT_STATUSES`: received, planned, in progress, on hold, done, declined; `portal_status_tag`), and a
date an open task has passed is marked late. A client puts their things in their own order of priority by dragging them in the portal (the core's
drag-and-drop, by a grip): their pieces of work (Your work), each work's sections, and the tasks
shared with them, on Tasks or within a section on a work's page (`ClientPrioritized`,
`client_priority` on works, scope items and tasks; `Portal::{Works,ScopeItems,Tasks}::PrioritiesController`,
tools `portal_prioritize_work`, `_section`, `_task`). The grip also takes ↑ and ↓ once focused, and on a touch screen gives way to up and down buttons
(the drag-and-drop controller's `moveUp` / `moveDown`). It's kept apart from the team's order
(`position`), so neither undoes the other: one ranking per peer group (a client's works, a work's
sections, all of a client's shared tasks), unranked ones after, and a drop puts the record before
the one it now sits above. Each move records `client.prioritized` or `work.prioritized`, so the team
sees it in History; a task's side panel says where the client puts it, and staff JSON carries
`client_priority`. Not while staff view as the client. Documents is a portal menu item of its own
(`Portal::DocumentsController`, `Client#client_documents`); a plugin can stand in for it
(`portal_nav … replaces: :documents`: its link takes the item's place and the page redirects to it). Task lists open on open tasks
(`?tasks=` on a piece of work, `?status=` on Tasks); Tasks and Documents search by name (`?q=`,
`portal_search`) and, with Requests, page (`portal_page`, 25 a page). The first page is the client's
work in the main column, each with how many of its shared tasks are done and the next date due, and
in the sidebar whatever plugins add (`:portal_dashboard`, then `:portal_home`); the core draws no
dashboard of its own. Requests lists everything asked
for on the client's behalf, each opening in the side sheet. New request opens in a modal (the portal
layout's `modal` frame) taking the piece of work it's about, a needed-by date (the task's due date)
and files, submits inside it and, sent, closes over the page; files sent with a request or a reply
become the task's documents, the contact's own and shown to the client (`PortalUploads`); a reply on a task's
discussion answers in place (`inline=discussion`, `portal/tasks/_discussion`), showing at once while
it's sent, and both keep unsent words as drafts. The portal has the staff pages' connection line and
sign-in handling (its own sign-in page is marked too), but no peek and no undo. Your account
(`Portal::AccountsController`) holds a contact's name, title and phone, the email switch, and where
they're signed in, with Sign out everywhere else. A portal session nobody has used in 90 days is over
(`Contact::PORTAL_SESSION_IDLE`, pruned nightly), and a sign-in link carries the page they were
after (`return_to`), so it lands there on any device. The top bar names the business with the
client under it; the footer says how to ask for something, by email too when the install takes
requests that way.

The plugins Runwell publishes (Agreements, AI, Account management, Cloudflare, Code, Factory, Google Ads, Meetings,
Outsend, QA, QuickBooks, Reporting, Stripe, Time tracking) each live in their own repository; what each does
and what it's the reference for (portal pages, webhooks, middleware, unattended agents, money,
model rules) is in `docs/plugins.md`. Read it before changing a contract they use.

## People and permissions

Three fixed roles (`User::Role`): owner (everything, including settings, plugins and
people), manager (closes work, deletes) and member
(does the tasks), plus client for someone at a client (a `Contact`: no permissions, the portal
only; Clients and the portal, above). Each permission in `User::Role::PERMISSIONS` names the roles that have it;
plugins add theirs with `Runwell::Plugins.permission key, :name, name:, roles:`. No custom
roles or permission builder. Check with `user.can?(:delete_records)`, and in views `can?`.

- Every controller declares its rule, or its actions are refused before they run
  (`Authorization`): `allow_staff` for anyone signed in, plus
  `require_permission :close_works, only: :close`. An action with no rule raises
  `Authorization::MissingRule`. Public pages (`allow_unauthenticated_access`) skip it
- Rules about a record live on the model and are checked in the action
  (`Document#deletable_by?`: its uploader, or anyone who may delete records)
- Hide what someone can't do (`can?` around the button or form); the controller still
  enforces it. Nest ReActionView state reads inside the `can?` check, never in one chain
- People join by invitation (`Invitation`, Users): an emailed, signed link
  that works once and expires in 7 days. Sign-up (`/signup`) only works while there are no
  users, and makes the first owner
- Two-factor sign-in (`User::TwoFactor`, `rotp`): a code from an authenticator app after the
  password (`Sessions::TwoFactorsController`, the pending sign-in in the session cookie for five
  minutes and five tries), or one of ten single-use recovery codes (HMAC digests, shown once). Set
  up and turned off (password) in Settings > Your account. It's required of everyone by default
  (`Setting#require_two_factor`, on for a new install; whoever manages people switches it in
  Settings > Your account, where Security used to be), which sends anyone without it to set it up
  (`Authentication#require_two_factor_setup`, browser sessions only), and resets someone's who
  lost their phone. Tokens and the portal are untouched; agents can't change any of it
- The one other way in is an emailed link for anyone who switches it on (`User#passwordless`,
  Settings > Your account; `Sessions::LinksController`, a button page so mail scanners can't use it,
  once, 15 minutes). No sign-in through Google, Microsoft, GitHub or single sign-on. It ends in
  `Authentication#sign_in_after_first_step`, so two-factor sign-in still follows
- People are deactivated, never deleted (`deactivate!` ends their sessions; their name stays
  on their history). Each has a page in Users (`users/show`): their name,
  address and role, a password reset email or a password set for them (`User::Access`), their
  sessions (sign out everywhere), their connected apps (cut them all off), two-factor, recent
  sign-ins, and deactivation. Your own password and two-factor stay in Your account. Pickers and
  mentions list `User.active.ordered`. The last active owner can't be demoted or deactivated

## Agents

Most use is expected to come through an AI harness, so anything the UI can do, an agent can
do, through the same controllers: there is no separate API.

- **Every action declares how an agent reaches it**, next to its authorization rule:
  `agent_tool :create_client, on: :create, title:, description:, params: { client: { name: "string!" } }`
  (a list is `"integer[]"`, or `[ { title: "string!" } ]` for a list of objects; `[ "a", "b" ]`
  is one of those values)
  or `agent_exempt :preview, reason: "…"` (`AgentTools`). `new`/`edit` and public pages are
  exempt on their own. `agent_exempt` only keeps an action out of the tools; what only a person
  may do in the browser (tokens, passwords, two-factor, sign-in methods, secrets and keys to other
  services, webhooks, View as) is `browser_only`, which also refuses any token that calls it
  straight (`forbidden`), so a token can't mint another or change how someone signs in An undeclared action raises in development and test;
  `bin/rails agent:coverage` lists them all. Keep `params:` in step with the action's
  `params.expect` (types: string, text, integer, number, boolean, date, file, an array of
  values, a nested hash; `!` = required; path params come from the route)
- **Reads** need a `.json.jbuilder` view beside the HTML one. Start each record with
  `json.merge! agent_ref(record)` (type, id, `record` "Type:id", display name, `url`) and give
  every view a `summary`. Rich text goes out through `agent_text`
- **In-place forms answer with a stream**: a form inside a section on the record's own page (the
  notes composer, a Tasks section's Add a task) sends `inline`, and its action renders a turbo
  stream replacing that section and the flash rather than redirecting back to a whole new page;
  anything else (agents, the quick action tray, a plain HTML post) still gets the redirect
- **Writes need nothing extra**: `AgentResponses` turns the redirect + notice into
  `{ status: "ok", summary }`, a redirect with an alert or a 422 re-render into
  `{ status: "error", errors }` (from the record the action was saving). So write notices a
  model can act on, and give `redirect_back` a sensible fallback
- **Anything that reaches a client** (sends, emails, portal visibility) declares `confirm:`;
  the tool then answers `needs_confirmation` with a preview until called with `confirm: true`.
  A tool that reaches the client only with some arguments adds `confirm_when:` (the task tools,
  when `client_visible` is true); a task an agent adds stays internal unless it says otherwise
- A tool runs the real action with the caller's token (`Agent::Dispatch`), so roles,
  permissions, validations and events are the UI's. `Agent::Catalogue.for(user)` offers only
  what their role and switched-on plugins allow; `me` explains what's withheld
- Every person has an agent user (`User::Agent`: `agent_owner_id`, "Ted's agent", made on
  creation or first use). A bearer token belongs to its person but its requests run as that
  person's agent (`Current.user`), so writes read "Ted's agent via Claude": the agent has its
  person's permissions exactly (`can?` delegates), can't sign in, and is kept out of pickers and
  mentions (`User.people`). Agent writes carry `Current.source = "agent"` and the app's name as
  the event's actor label. Model verbs default `source:` to `Current.source`, never `"app"`
- The AI button on tasks (`tasks/_ai_brief`, key `c`) copies `Task::Brief` from
  `/tasks/:id/brief` (also the `brief_task` tool): the tasks, agreed scope, notes, other dated tasks and
  the `runwell` commands to report back. Plugins add sections with
  `Runwell::Plugins.agent_brief key, ->(task, base_url) { markdown }` (Code adds repos and a branch)
- Auth: `AccessToken` (personal from Settings > Connected apps, or OAuth), digests only.
  OAuth 2.1: discovery at `/.well-known/oauth-*`, dynamic registration, PKCE (S256), consent at
  `/oauth/authorization`, hourly tokens with refresh, revocation. `/mcp` takes bearer tokens
  only, never a session cookie. Agents can't mint or revoke tokens
- Plugins declare tools in their controllers the same way; they appear while the plugin is on
- The CLI has no per-tool code: every command is a tool from `tools/list`. Don't add
  commands to it for app features; declare a tool instead. Its own commands are only about the
  CLI: `login` (`--read-only`, `--client` for a contact's portal), `doctor` (`--brief` is the Claude Code SessionStart check),
  `update`, `mcp` (`--read-only`), `agent setup` (a managed skill, marked, refreshed by `update`,
  never overwriting a hand-edited one), and `installs`, `use`, `logout [host]`. It keeps a sign-in
  per Runwell (`~/.config/runwell/logins.json`, by address; the old one-sign-in `config.json` is
  read once and replaced), written under a lock so two runs can't lose a refreshed token. A
  command goes to `--on <host>`, else `RUNWELL_URL`, else the default, and a token is only ever
  sent to the Runwell it was issued by (never the default's to another address). `Task::Brief`
  puts `--on` on its commands. `update` and the doctor's version check use the Runwell the CLI
  was installed from, whichever is in use; `agent setup` writes to `CLAUDE_CONFIG_DIR` when set,
  and with `--on` ties that Claude Code to the Runwell (`env.RUNWELL_URL` in its settings). Output is JSON when piped; `--ids-only`, `--count`,
  `--field a.b` trim it. Exit statuses follow the error codes (`runwell help exit-codes`)
- **AI activity** (`/ai`, `AgentActivitiesController`, linked from Intake, the `agent_activity`
  tool) is where people review what agents did: every event whose actor is an agent
  (`Event.by_agents`, `by_agent_of(person)`; sign-ins and settings stay in the audit log), your own
  agent's by default, a teammate's or everyone's, by area (`Event.in_area`, shared with the audit
  log) and period, each row linking to its task (side panel) or record (peek)
- **Errors are machine-readable**: every agent error carries a `code` (usage, not_found, ambiguous,
  auth, forbidden, refused, invalid, read_only, paused, rate_limited, failed) and a `hint` (`Agent::Errors`); a redirect with
  an alert is `refused`, a 422 is `invalid`. A success whose tool declares `next_tools` also
  carries `next`: runwell commands with the ids from the call or its answer filled in
- **Read-only access**: a token (personal, or OAuth with scope `runwell:read` / the consent
  checkbox) may be read-only. It is offered only GET tools and any non-GET request with it is
  refused with `read_only` (`ApplicationController#refuse_read_only_writes`)
- **Names stand in for ids**: `Agent::Dispatch` resolves path ids and refs, id params
  (`Agent::Resolver::PARAMS`: client_id, owner_id…) and "Type:name" records through
  `Agent::Resolver` (exact, prefix, contains, search). One match is used, several answer
  `ambiguous` with `candidates`, none `not_found`; the schema types those params integer or string.
  `resolve` looks a name up directly. A new id param naming a record goes in `PARAMS`
- **Around every call** (`Agent::Dispatch#call`): a paused token answers `paused`; a token over
  `Agent::RateLimit` (RUNWELL_AGENT_RATE_LIMIT a minute) answers `rate_limited` with
  `retry_after`; a write with an `idempotency_key` already seen answers the stored response with
  `replayed: true`; and the call is logged (`AgentCall`, 90 days), shown per connection in
  Connected apps, where a person pauses one and an owner sees everyone's
- **`changes`** is how a scheduled agent catches up: events after a cursor (or since a time),
  oldest first, optionally for one client or work. MCP prompts (`Agent::Prompts`) and
  resources (`Agent::Resources`, runwell:// URIs read through the show tools) sit beside the tools
- **Clients' agents**: an `AccessToken` (or `OauthGrant`) belongs to a user or a contact. Staff
  surfaces take staff tokens only (`authenticate_staff`); the portal takes a contact's
  (`Portal::BaseController#require_contact_token`), and `/portal/mcp` (`Portal::McpController`)
  offers only portal tools (`Agent::Catalogue.for_contact`), declared in the portal controllers
  like any other (`portal_*`) with JSON views that show what the portal shows, with links to
  portal pages (`portal_agent_ref`). Names resolve within
  the contact's client. OAuth for a request naming the portal resource or scope goes to
  `Portal::OauthAuthorizationsController`, which signs the contact in by emailed link.
  `docs/agents.md` is the guide

## In-app AI

The third way to use AI with Runwell, beside a local harness over MCP (coding belongs there) and a
chat app over MCP, is an assistant inside the app: the AI plugin
(`Martin-Business-Consultants/runwell-ai`, key `ai`; its AGENTS.md is the guide). Until 2.18 it was
in the core. The core keeps only what the plugin reaches it through: the slots it fills (the nav's
Ask button, home, the client, tasks and section sidebars, each note row, the
portal's header), `Runwell::Plugins.shortcut` for its `i` key,
`Runwell::Plugins.ai_prompt` (other plugins' questions for it), and `Agent::Dispatch.run_as`, which
runs a tool as the person with a one-call `assistant` token. `ruby_llm` stays in the Gemfile, since
plugins use only the core's gems; its tables (`ruby_llm_*`) are the plugin's (`tables:` in
`config/plugins.yml` keeps them out of `schema.rb`). `settings.ai_*` and `clients.ai_excluded` are
left from the core's AI, read by the plugin's first migrations, and dropped in a later release.

## Custom fields

What an install records about clients, work and tasks beyond the core (a plumber's
property address, a firm's matter number, a studio's client website) is a custom field, not a
column: the core only holds what every business needs. Defined in Settings > Fields
(`CustomField`: model, label, a key fixed at creation, kind, choices, `listed` as a table
column, `client_visible` in the portal); values live in `CustomValue` as text (money in
cents, dates ISO) and are set by key, `record.update(custom_fields: { "renewal" => "2026-12-01" })`,
which the create and update tools take as `custom_fields: {}`. The `CustomFields` concern checks
each value against its kind, and search indexes them. Forms render them with
`custom_field_inputs form, record` (a helper, since partials can't render in `form_with`);
pages with `render "custom_fields/values", record:`. Rules: information only, nothing acts on
a custom field; never required; a kind can't change once it has values; archiving keeps
values; a plugin keeps its own data in its own tables, never in a custom field. On record pages
they're laid out one by one with the rest (`custom.<key>`, Template mode below).

Who on staff sees a field is a permission on the field (`CustomField#visible_to`: the roles besides
owners who see it; nil for everyone, `[]` for owners only), set in Settings > Fields or from its
"who sees it" pill while arranging (`record_fields/visibility`). It's enforced where values are
read, not where they're drawn: `CustomField.for(model)` leaves a field out for anyone else
(`seen_by(Current.user)`, an agent counting as its person), and every page, table column, the side
panel, JSON for agents and saving (`record.custom_fields`) goes through it; search indexes only
fields everyone sees (`custom_search_text`), and a restricted field is never shown to clients. A
new place that reads custom values reads them through `CustomField.for` or `record.custom_fields`,
never `CustomValue` directly.

## Template mode

Owners arrange each kind of record's fields for the whole install, on the record's own pages: the
layout icon in the header (`record_fields/arrange_button`) opens a bar (`record_fields/arrange`,
the `record-layout` controller) where fields are dragged between the working column, the sidebar
and a Hidden tray, or moved with the keys (← → a column, ↑ ↓ their place, Delete hides, Enter
brings one back); Done saves (`Settings::LayoutsController`, `arrange_layout` / `reset_layout` /
`show_layout`, `settings.layout` in the audit log). One arrangement per kind (`client`, `work`,
`task`, `contact`, `user`; a person's page is one column, so order only; and `portal_work`, the
portal's cards, Clients and the portal below) drives its new, edit and
show pages alike (`RecordLayout`, kept on `Setting#layouts`), and for tasks the side panel (its
fields in that order, hidden ones left out) and the quick-action form (its rows: what needs doing beside
where it goes, the details, lead beside who else, due beside the client switch, in the order of
each row's first field; a hidden field drops out of its row). Custom fields start in the sidebar on clients and work, the working column elsewhere. Each field is a partial,
`record_fields/<kind>/_<key>` (custom fields `record_fields/_custom`), drawing an input when given
a form builder and its value (a `dt`/`dd`, or nothing when the header already shows it) without;
`record_fields/zone` lays out a column, `record_fields/main_card` and `aside_card` the cards
(`record_card`; the zones carry the `record-layout` targets, so the cards' markup is free).

A record's own page (clients, work, contacts, people) changes in place: nobody goes to an edit page
to change a field. Its zones render with `in_place: true`, which gives each field a hidden form of
its own (`inline=field`), so a save sends only that field; the `save-on-change` behavior submits it
when it changes (not while arranging), and the record's `update.turbo_stream.erb` redraws each place
it shows (the page's header and zones, its table row) with the toast, or puts the old value back
and says why. The title is `layouts/shared/_record_title` in the header (`e` focuses it), and what
the header draws instead of the columns is `header_fields(kind)` (a client's status picker, a work's
description in its info dialog: rich text saves with Save or ⌘/Ctrl+Enter, never per keystroke,
and Esc puts it back, the `save-when-dirty` behavior). The edit pages stay for row actions,
Cmd-click and plain posts.

The limits, kept on purpose so this stays a way to arrange a page and doesn't become a form
builder:

- **Placement, order and visibility only**, on record pages. Nothing changes what's stored, what's
  required or what an agent can set, and a hidden field still shows wherever else the record does
  (the side panel, tables, the portal, exports). Required fields can't be hidden
- **One layout per kind per install**, set by owners. No per-person or per-role layouts, no
  conditions ("show when…"), no required custom fields. Who may see a custom field is a
  permission on the field itself (Custom fields, above), set from template mode but enforced
  everywhere its value goes; everyone sees the same arrangement, less the fields they can't see. Layouts are stored per kind so a per-label
  variant (`work:service`) could come later without changing their shape
- **Headers and in-place widgets stay hand-built**: titles, the work's meta line and info button,
  status and owner pickers. Fields are what move
- **Field keys are a contract** (`RecordLayout::DEFAULTS`, docs/plugin-contract.md): renaming one
  needs a migration of saved layouts; a field a release adds joins its default column, one it
  removes is dropped
- **Fields live outside the `<form>`** and join it by id (`form="…"`, the `form_id` local), so a
  field can sit in either column and still save. Every field widget must respect it: helpers
  take `form:` (`date_input`, `money_field_tag`, `rich_text_field form_id:`, comboboxes copy it to
  their hidden fields, `custom_field_input_for`), and JavaScript finds a field's form with
  `element.form` (or `[data-form-for]` around buttons), never `closest("form")`

## Audit log

Settings > Audit log (owners, `audit_log` tool) lists every `Event`, filtered by area, person and
period, and downloads as CSV. Security events have the person (`User`) or the install
(`Setting`) as their subject: `user.signed_in` (method, two_factor, ip, browser),
`user.sign_in_failed`, `user.two_factor_enabled / _disabled / _reset`, `user.recovery_codes_renewed`,
`user.role_changed`, `user.profile_changed`, `user.password_set`, `user.password_reset_sent`,
`user.signed_out_everywhere`, `user.connections_revoked`, `user.deactivated / reactivated`,
`user.link_sign_in_on / _off`, `user.exported`, `settings.two_factor_required`,
`settings.plugin`, `settings.custom_css`, `settings.webhook`, `settings.bot_check`, `settings.layout`. Those subjects
(`Event::SECURITY_SUBJECTS`) stay out of `changes`. A new security-relevant action records one.

## Webhooks

Settings > Webhooks (owners; agents may only `list_webhooks`) sends events to outside addresses:
`WebhookEndpoint` (url, encrypted secret, optional kinds like `task.*`, `include_security` for
User / Setting events), dispatched from `EventPublishJob`, one `WebhookDelivery` per event,
delivered by `WebhookDeliveryJob` with retries (about a day). The body is JSON (`id`, `kind`,
`occurred_at`, `actor`, `subject` with name and url, `payload`), signed as
`X-Runwell-Signature: sha256=HMAC(secret, "#{timestamp}.#{body}")`. Twenty failures in a row
switch an endpoint off; deliveries are kept 30 days.

## Export

Settings > Export (owners, `create_export` / `list_exports`) makes one .zip of everything
(`Export`, built by `ExportJob`, emailed when ready, kept a week): every table, the core's and
plugins', as JSON and CSV with ids intact, and every stored file, with a README. It skips
sessions, tokens, grants, invitations and the search index (`Export::SKIPPED_TABLES`) and drops
any password, secret, token or key column (`SECRET_COLUMNS`). A new table holding secrets goes in
the skip list; a new secret column needs a name the pattern catches. A backup (`kind: backup`, the
database itself and every file, secrets included) is made only in the browser: a token asking for
one is refused, and `create_export` offers only the data kind.

## Releases and updates

Every install is its own copy, so a change reaches an install only when it updates. This
repository is public (FSL-1.1-MIT, `LICENSE.md`). A release is a `vX.Y.Z` tag made by
`bin/release 2.1.0` (writes `VERSION`, commits, tags, pushes); `.github/workflows/release.yml`
publishes it. Nothing that names a deployment or a client is tracked (`config/deploy*.yml`,
`.kamal/secrets*` and QA source files are ignored): everything committed is public. `Release` is the newest one GitHub lists, checked
nightly (`ReleaseCheckJob`) and by Check now, kept on `Setting#latest_release`. Owners see it in
Settings > Updates, whose button makes an `Upgrade`: `hoster` (an install on KamalCloud, whose Runwell
template passes `HOSTER_URL` / `HOSTER_APP` / `HOSTER_ENVIRONMENT`, given an admin's KamalCloud token in
Settings > Updates or `HOSTER_TOKEN`) moves the app's image tag and deploys it through KamalCloud's API,
so kamal-proxy starts the new container beside the old and switches only once it's healthy: no downtime,
and a release that can't boot never replaces the running one (`Upgrade::Hoster`); `in_place`
(any Docker install) downloads the release's bundle into the data volume and restarts on it,
like WordPress (`Upgrade::InPlace`, run by `bin/docker-entrypoint`); each bundle carries its Ruby
(`ruby/`, switched to by `config/bundled_ruby.rb` from `config/boot.rb` and `bin/thrust`, checked by
`bin/check-bundle` in the release workflow), so only a `RUNWELL_BASE` change (system packages,
the pinned Debian) needs a new image, deployed through GitHub when the install has a token, `local`
runs `bin/update <tag>` in the background (`Upgrade::Local`), `github` starts
`.github/workflows/deploy.yml` for the install's Kamal destination (`Upgrade::Github`), `manual`
shows the command. An upgrade succeeds when the install boots on the new version, and fails when
its run fails or goes quiet (`Upgrade#reconcile!`). See `docs/install.md`.

In production `db:migrate` and `db:prepare` back up every database with pending migrations
first (`lib/tasks/backup.rake`). Updates run unattended, so **every migration must be safe on a
live install**: add columns and tables in one release; remove or rename them only in a later
release, once no code reads them. No migration may depend on a person running a task by hand.
SQLite copies and drops a table to rename, change or remove one of its columns (`rename_column`,
`change_column`, `remove_column`), and inside a migration's transaction foreign keys stay on, so the
drop cascades: renaming a column on `tasks` in 5.0 deleted every assignment
(`20261108150000_restore_task_lead_assignments`). Before altering a table's columns, check what
points at it with `on_delete: :cascade` and copy those rows aside and back, or use
`execute "ALTER TABLE … RENAME COLUMN …"`, which SQLite does in place.

## Settings and names

Settings (the gear, `/settings`, where owners land on Address) has Address (where the install is reached: every emailed link points there, `Runwell.host`, before `APP_HOST`), Appearance, Names, Fields, Sidebar (the nav, `NavLayout`), Email, Plugins and Updates (`manage_settings`), People (`manage_people`), and Connected apps and Help for everyone. They're listed in a grouped sidebar (`settings/_nav`, `ui/app-settings.css`), each plugin's settings page nested under Plugins. A settings page starts with `render "settings/header", current: :key`, which sets the header's title and hands the sidebar to the application layout (`content_for :settings_nav`); pages add no navigation of their own. Names are core: the words for
client, work, scope item and tasks. Defaults live in `config/locales/terms.en.yml`; overrides in
`Setting#terminology` (one row, single tenant). In views use `term(:work)`,
`term(:work, count: 2)`, `label_term(label)` and `label_options(current)` — never
hard-code "Work", "Project", "Client" or "Tasks".

Its Types tab is the kinds of work, each a record (`WorkType`, `Settings::WorkTypesController`
and its `archive`, `merge`, `position`; tools `list_work_types`, `create_work_type`,
`update_work_type`, `delete_work_type`, `archive_work_type`, `restore_work_type`,
`merge_work_type`): a name, plural, ref prefix (unique, so refs never collide; a new one applies to
new refs only) and how its work runs: shape (fixed scope or recurring), for recurring a cadence
(`Cadence`: weekly, every two weeks, monthly, quarterly, yearly) and a check-in (a task repeating
each period for whoever started the work, to look back on it), and the sections new work starts
with (`Work#start_from_type`, not for imports). New work takes its type's shape and cadence unless
told otherwise; work already started keeps its own. Project, work order and service are the system
types (`WorkType::SYSTEM_KEYS`, put back by `WorkType.ensure_system!` if missing): renamed,
re-prefixed or switched off, never deleted or merged. A type's key comes from its name and never
changes (`works.label` holds it); one you added is deleted only while nothing uses it, else
switched off (archived: not offered for new work, kept by what has it) or merged into another
(its work moves, refs kept, each recording `work.retyped`). Read types through `WorkType.cached`
(once per request, `Current.work_types`), `Work.labels` or `label_options`, never a fixed list;
`Work::LABELS` is the deprecated three. A tool param whose choices are the install's takes a
lambda (`label: -> { WorkType.active_keys }`).

A task may repeat (`Task::Repeats`, `repeat`: a `Cadence` key, set in its side panel or by the
task tools): marking it done makes the next one, due a period after it (skipping periods already
gone), with its title, description, section, people and visibility; the repeat moves onto the new
task and the old one records `task.repeated`. Nothing repeats on closed work, for a client that
isn't active, or when a sunset marked it done. The answer to the status change brings the new
task onto the page (`turbo_stream.refresh`).

## Appearance

Settings > Appearance sets the install's default theme (system, light, dark), color
scheme, corners and font, plus a logo and favicon (Active Storage on `Setting`). Each
layout's `<html>` carries them as `data-scheme`, `data-radius`, `data-font` and
`data-default-theme` (`appearance_data`); `appearance.css` turns them into the palette tokens (which `rune-theme.css` hands to rune_ui),
and the page previews a change instantly (`appearance` controller) before saving.
A person's sun/moon choice (localStorage) beats the install's default theme.
Text size (`Setting#text_size`: small, default, large, larger) sets `data-text-size`, which scales
the root font size (16px times `--text-scale`, `rune-theme.css`; rune_ui's text steps, the body 13px); a person's own choice in
Settings > Your account (`User#text_size`, blank follows the install) beats it. Every font size in
the stylesheets is rem or em so it all scales; tables size their columns from what they hold, so
they follow.

Every border radius in the stylesheets goes through two variables so Corners reaches the
whole UI: ordinary corners are `calc(<size> * var(--radius-scale, 1))`, pill shapes are
`var(--radius-pill, 99rem)`, true circles stay `50%`, and every control (buttons, inputs,
selects, toggles, tags) uses `var(--radius-control)` so they always match. A textarea is a box, not a control: it takes
`var(--radius-lg)`, since round corners make the control radius a pill (rune_ui's forms
stylesheet). The Lexxy editor keeps Lexxy's own corners (`--lexxy-radius`), never the app's. Write new CSS
the same way.
Schemes and fonts override the palette's unlayered tokens, so they are unlayered too.
Custom CSS (Settings > Appearance, `Setting::CustomCss`) is a theme: values for the design tokens
in `docs/theming.md`, the contract (tokens stable across releases, class names not). It is served
from `/theme/:digest` (`ThemesController`, never a `<style>`), linked last and unlayered on staff
pages, and on the portal only with `custom_css_everywhere`; `?theme=off` skips it.
No `@import`, no `url()` but `data:`. `ThemeBrief` (Copy brief for AI, the `theme_brief` tool) is
that guide with the install's current choices, for an AI to write one; `update_appearance` takes
`custom_css`. A new token worth theming goes in the guide's tables.

