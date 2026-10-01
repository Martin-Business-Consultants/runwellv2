# Runwell v2 — Project Guide

The core of an agency's project management: who we work for, what we agreed,
what is happening against it, what came in, and what needs a person now. No
money, no time tracking; see `docs/future_apps.md` for everything left out.

## Stack

- Rails 8.1, Ruby (see `.ruby-version`), SQLite, single tenant
- Hotwire (Turbo + Stimulus) over importmap and ERB views; plain CSS in
  `app/assets/stylesheets` served by Propshaft, modelled on Fizzy (`../fizzy`)
- Search: ActiveSearch (`rails-active_search`) over SQLite FTS5, one polymorphic
  `:searchable` index (`config/search.rb`, `SearchableDocument`)
- ReActionView (https://reactionview.dev) compiles every `.html.erb` through
  Herb (`config/initializers/reactionview.rb`): validation overlays, debug mode
  and reactive template state
- Staff auth: Rails' generated authentication (`Session`, `User`). Sign-up only makes
  the first owner; everyone else joins by invitation. Clients never have passwords:
  portal sign-in and approvals are signed, expiring links
- Time zones: stored in UTC, shown in the agency's zone (`config.time_zone`, Eastern unless
  `TIME_ZONE` says otherwise). A client may have its own (`Client#time_zone`, blank = ours); its
  portal (`Portal::BaseController`), approval pages and emails run inside `client.in_time_zone`.
  Staff pages and agent input stay in the agency's zone. A record read before the zone switched
  keeps the old zone, so client-facing templates call `.in_time_zone` on times they show
- Solid Queue for mail; letter_opener_web at `/letter_opener` in development. Production mail
  is any SMTP server from the environment (`SMTP_*`, see `docs/install.md`); the Outsend
  plugin routes it through Outsend instead, per message, with no restart. The sender is
  `Setting#mail_sender` (Settings > Email), falling back to `MAIL_FROM`, whichever way it goes out
- One install per deployment, its own data directory (`RUNWELL_DATA_DIR`: databases and files).
  Docker with Kamal by default (`config/deploy.yml`); a plain install is `bin/install` and
  `bin/update` (`docs/install.md`). `VERSION` is the core's version (`Runwell::VERSION`)
- Agents: an MCP server at `/mcp` (the `mcp` gem), OAuth 2.1 for connectors, bearer
  tokens, and the `runwell` CLI (`lib/cli/runwell`, served at `/install/cli`). See Agents

## Commands

| Command | Purpose |
| --- | --- |
| `bin/setup` | Gems, npm, db:prepare, seeds |
| `bin/dev` | Rails + jobs (`Procfile.dev`) |
| `bin/rails test` | Minitest with fixtures |
| `bin/rubocop` | Lint (omakase) |
| `bundle exec herb lint app/views` | Lint templates (Herb) |
| `bin/rails search:reindex` | Rebuild the search index from every searchable record |
| `bin/rails agent:coverage` | Every staff action with its agent tool, or why it has none |
| `bin/rails db:seed:replant` | A sample web / local search / ads agency. Logins `ted@brem.io` (owner), `sarah@` (manager), `marcus@`, `priya@`, `jordan@runwell.app` (members), all `password` |

## The five things the core answers

1. **Who we work for, and who can say yes** — `Client`, `Contact` (`portal_access`,
   `can_approve`)
2. **What we agreed** — `Engagement` (ref like WO-12, P-3, S-4; label project /
   work_order / service; shape fixed / recurring) holds `AgreementVersion`s
   (initial, change_order, revision, add_on). A version is a draft until sent;
   sending snapshots and hashes it and freezes it forever. `Approval` records
   the client's decision (by link or recorded with evidence). Approving creates
   one `Todo` per scope item. Nothing is "billable": everything is a project,
   work order or service
3. **What is happening** — `Todo`, at `/work` (old `/todos` links redirect; helpers stay `todo_*`) (owner, status: planned, in progress, in review, blocked,
   done; due; table or kanban; agents finish into in review for a person to mark done),
   `Commitment` (a promise by us or the client with a date; final once
   resolved), `Event` (append-only, every write of consequence), `Note`
4. **What came in** — `Request`: a client ask with a source. Triage promotes it
   to a new engagement, a scope item on a draft, a todo, or a commitment, or
   dismisses it. Portal contacts create requests
5. **What needs a human** — `Briefing` builds the home page from named queries:
   questions, requests to triage, awaiting client, drafts ready, overdue and due
   commitments, blocked and overdue work. `Question`
   is what an agent asks a person. Above it, until the required steps are done or the owner
   hides it, the first-run checklist (`Setup`, `briefings/_setup`) checks itself off from what
   exists

Rules the code enforces: sent versions, approvals and events are immutable;
every event has a source; internal estimates and estimate notes never reach a
client (portal and approval pages render `AgreementVersion#snapshot`, never live
scope items).

## Conventions

- Rich models, skinny controllers, no service objects. Domain verbs are model
  methods (`send!`, `decide!`, `promote_to_change!`, `resolve!`)
- State is derived, never typed in (`Engagement#state`, `ScopeItem#delivery_state`)
- Views are ERB templates rendering models directly; no serializers
- Money is integer cents everywhere: columns, params, agent tools (`price_cents: "integer"`)
  and JSON (`*_cents` beside the formatted dollars). Dollars exist only on screen: a form
  field is `money_field form, :price_cents`, whose `money` Stimulus controller shows and
  takes dollars and submits whole cents; `money(cents)` formats for display
- Signed-out and client-facing pages use `layout "public"`; staff pages use
  the application layout
- Multi-line text is rich text: Lexxy (`<lexxy-editor>`, Fizzy's editor)
  writing HTML into the plain text column. In forms use
  `rich_text_field form, :body`; to display use `rich_text record.body`, which
  sanitizes and keeps older plain-text values readable. Never a `text_area`.
  No attachments (no Active Storage). Search indexes the plain text
  (`Searchable#to_search_document`)
- A snippet to read or copy (a command, a request body) is `code_block code, language: "bash"`
  (or `"json"`, `"ruby"`, any Prism name Lexxy carries), never a bare `<pre>`: Lexxy's
  highlighter colours it as it does code blocks in rich text (`code.css`)
- Every date is a native `<input type="date">` through `date_input form, :due_on` (or
  `date_input_tag` without a form builder), which adds the `date-field` controller: a click
  opens the browser's picker; `t` today, `+`/`-` a day, Delete clears. Never a text field for a
  date, and no date-picker library
- Never inline CSS: no `style` attributes and no `<style>` tags in views. All
  styling lives in `app/assets/stylesheets`
- Do not write tests. Don't add new ones or extend existing ones unless asked

## Frontend

Reach for these in order, and stop at the first that fits:

1. **ReActionView state** for UI state that stays on the page: anything that
   opens, closes, switches or reveals. Declare it in the template with
   `<%# herb:state (open: false) %>`, change it with `data-herb-toggle`,
   `data-herb-set`, `data-herb-reset`, `data-herb-increment` or
   `data-herb-decrement`, and read it with plain `<% if open %>`. See
   `layouts/shared/_confirm.html.erb`
2. **A Fizzy Stimulus controller** for behavior markup can't express (focus,
   hotkeys, submitting on change). Copy it from
   `../fizzy/app/javascript/controllers` with any helpers it imports. A
   controller that needs template state uses ReActionView's `useState(this)`
   instead of touching the DOM
3. **A new Stimulus controller** only when neither of the above fits

Every trash icon opens Fizzy's modal delete dialog,
`render "layouts/shared/delete_dialog", name:, path:, message:` — never a native
`turbo_confirm`. A destructive action on a record's own page (delete, archive) confirms inline with
`render "layouts/shared/confirm", trigger:, title:, body:, button:, path:`,
which is ReActionView state with no JavaScript.

Boards are Fizzy's board wholesale, not a new take on it: the same
`card-columns` markup and data attributes, `column_tag` / `column_frame_tag`
(`ColumnsHelper`, verbatim), the stream / doing columns / closed anatomy, an
expander per column, maximize pages, cards loaded into column frames, card
previews in Fizzy's `card` markup, and drops posting to one endpoint per
destination (`Columns::…::Drops::{Streams,Columns,Closures}Controller`) that
answer with a morphing `turbo_stream.replace` of the target column. The Work
board (`todos/board/*`, `todos/columns/show`, `columns/todos/drops/*`) is the
reference. The only departure: column colors come from classes
(`todo-board.css`), not inline styles.

Staff pages have a left nav (`layouts/shared/_sidenav`, `sidenav.css`): home and the core
sections with icons (`sidenav_link_to`, which marks the current one), plugin links under
Plugins, and at its foot the theme toggle, settings and sign out ("/" and `?` are keys only). Below
800px it runs across the top. Every index shows its records as cards or a table, and has no
heading: the nav marks the current section. The controller sets `@view = index_view`
(Work adds `extra: %w[board]`), which reads `?view=` or the install's default (Settings >
Views). The page starts with
`render "layouts/shared/index_toolbar", view: @view, new_text:, new_path:`: the page's
quick_filter pills on the left (wrap them in `<% content_for :index_filters do %>` before
rendering the toolbar), and on the right the Cards / Table icon toggle and the New button,
spanning the page's column. Then either a `cards cards--grid` grid of
`render "layouts/shared/card", path:, title:, id_label:, context:, meta:, status:`
(Fizzy's card markup, colored by status) or a `<table class="data-table">` in
`panel shadow center index-table`, whose last cell per row is
`render "layouts/shared/row_actions", name:, edit_path:, delete_path:` (pass nil for an
action the record doesn't allow: engagements delete only while never sent, commitments
and requests only while open). Lists page Fizzy's way (geared_pagination, `PaginationHelper`, the `pagination`
controller): the action wraps its records in `paginate` (HTML only; JSON for agents stays whole),
the cards grid wraps its loop in `with_automatic_pagination :name_cards, @page`, and a table's
`<tbody id="<%= pagination_frame_id_for(:name_rows, @page.number) %>">` ends with
`table_next_page_row :name_rows, @page, columns:` on a `<table>` carrying the pagination
controller in discard-frame mode. The next page loads as you scroll. Mark each card or row `data-filter-target="item"` so "/"
filters it. The filter itself is one control at the foot of the nav
(`layouts/shared/nav_filter`): out of sight until "/" focuses it, and absent on pages with
nothing to filter. Pages never render their own. The filter controller lives on
`#global-container`.

A record's page, and its new and edit pages, are `settings settings--split`: the working
column (2/3: the description, versions, work, the form) and an
`<aside class="settings__panel settings__panel--side">` (1/3) that opens with a Details
`<dl class="record-facts">` and holds the smaller sections (contacts, plugin panels, notes or
history, delete or archive). New pages use the sidebar for what comes next
(`record-steps`) and related records. Never a lone centered card for a form. The title and
the record's actions share one row (`page-heading`, `page-heading__actions`), not the header.
A record with several sections (clients, engagements, work, scope items) puts them in tabs
in the working column: `record_tab(key, label, count:)` plus `plugin_record_tabs(:client_panel)`
(one tab per plugin panel), `current_record_tab(tabs, default)`, and
`render "layouts/shared/record_tabs"` inside `<turbo-frame id="record_tab" target="_top">`.
A tab is a `?tab=` link that only reloads the frame; the first heading in a tab is hidden
since the tab names it. The sidebar keeps Details, the few things always needed (contacts),
History, and destructive actions. A section's add action is one small outlined button
(`btn txt-small` with the add icon) in a `section-actions` row after its list, a `<details>`
when it opens a form; the one filled button on a page is its next step. A record page names
itself at the top left of its first panel, `<h1 class="page-title"><%= @page_title %></h1>`, not in the header, which
keeps only the actions (Edit, Copy for AI). Up a level is `parent_page label, path` in the
header block: a `<link rel="up">` that Esc follows, never a Back button.

Guide people through the hierarchy rather than documenting it. A record page says what happens
next (`engagement_next_step` under the engagement's state). An empty list says where its records
come from and links there (`todos/_blank`), since Work and Commitments are added on the
engagement or client, never from their index. Help (`settings/helps/show`) uses `term()` for every
name, and the `?` sheet links to it.

People show as their avatar, never their name: `person_tag user` (name as the tooltip and
for screen readers; `fallback: "Unassigned"` for nobody). Only a list of the people
themselves (Settings > People) prints names beside the avatars. A todo's owner changes in
place with `render "todos/owner_picker", todo:`, as its status does with `todos/status_dot`.

Filters on an index page are Fizzy's quick filters above the list, not
buttons inside the card: a row of
`render "layouts/shared/quick_filter", title:, param:, options:, current:`
inside `<div class="filters margin-block-end">`. Each choice is a link that
swaps one query param, so filters are bookmarkable and Back works; the
controller reads the params (`engagements#index`). Don't drive a list with
ReActionView state: in 0.6 a list stops refetching after the first change.

Styling works the same way: use Fizzy's CSS and utility classes (copy the
stylesheet from `../fizzy/app/assets/stylesheets` when it isn't here yet) and
write new CSS only when Fizzy has nothing that fits. Copy Fizzy's view
patterns too (`account/settings` lists, `panel`, `settings__section`,
`divider`).

ReActionView rules:

- Every partial declares strict locals on its first line:
  `<%# locals: (client:) %>`, or `<%# locals: () %>` when it takes none.
  Render partials by full path (`render "clients/form"`,
  `render partial: "clients/client", collection: @clients`)
- A template with state names its rendering mode above the state:
  `<%# herb:slots server %>` when a branch holds Ruby output (paths, forms,
  CSRF tokens), `<%# herb:slots client %>` when branches are plain markup
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
  (`if engagement.draft_version … elsif starting`): the state change is
  never sent. Nest the state `if` inside the Ruby one
- State in attributes isn't reactive (`<% if open %>hidden<% end %>` never
  updates), and state in a partial rendered once per row can't be told apart
  between rows. For a per-row or inline "add / resolve" form, use a native
  `<details>` with a button-styled `<summary>`, which the morph after submit
  closes again (`commitments/_commitment`)
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
  Indexing is inline on save; no job
- Add the model to `lib/tasks/search.rake` and to `search_result_path` in
  `SearchesHelper`, then run `bin/rails search:reindex`
- `Search.new(terms).results` cleans the terms and returns records ranked by
  relevance, with `record.hit.highlight(:title)` and `(:content)` HTML-safe
- The search bar is Fizzy's (`bar/_bar`, `bar_controller`), rendered in the
  application layout footer for signed-in staff. It shows only once opened (`s`, ⌘K): the
  bottom of staff pages stays clear but for the notification bell (`corner.css`)

## Keyboard shortcuts

Vim style, and everything reachable without a mouse. One Stimulus controller on `<body>`
(`keyboard_controller`) handles every key; nothing else listens for letters. Keys act outside
inputs and open dialogs; `⌘/Ctrl+Enter` saves from anywhere in a form. The `?` sheet
(`layouts/shared/_shortcuts`, listed in `_shortcut_list`, also on Settings > Help) is the
one place they are documented for people: add a new key there.

| Key | Action |
| --- | --- |
| `j` `k`, `gg` `G` | Move through the page's items (every `data-filter-target="item"`), first and last |
| `Enter` `o` | Open the item you're on |
| `e` `d` | Edit, or delete / archive / close (always asks first): the item you're on, else the record on screen |
| `Esc` | Drop the selection, then up a level (`parent_page`), cancel a form, close a dialog |
| `g` + `h c e w b m r n s` | Home, clients, engagements, work, board, commitments, requests, notifications, settings; `g 1`… plugin pages |
| `n` `v` `/` | New record, next view (cards / table / board), focus the page filter |
| `s` or `⌘K`, `a`, `?` | Search, quick actions, the shortcut sheet |
| Board: `h` `l` `j` `k`, `H` `L` | Columns and cards (Fizzy's navigable lists), move the card a column |

Declare a key on the element it acts on: `data-keys="e"` clicks it, `data-keys-focus` focuses
it instead, `data-keys="g c"` is a chord, `data-keys="s, mod+k"` lists alternatives (`mod` is
⌘ on a Mac, Ctrl elsewhere). A key declared inside an item fires for the selected item only
(`row_actions` marks edit `e` and delete `d`); one outside any item is the page's. Show the
key on the button with `<kbd class="hide-on-touch">`. A new index page's "Add a …" button
renders `render "layouts/shared/new_button", text: "Add a client", path: new_client_path`.

## Mentions and notifications

Fizzy's, wholesale. Staff editors take `rich_text_field form, :body, mentions: true`,
which adds the `<lexxy-prompt trigger="@">` fed by `prompts/users`. A mention is an
Action Text attachment (`application/vnd.actiontext.mention`) holding the user's sgid,
stored in the HTML column. A model with rich text includes `Mentions` and names its
columns (`mentionable_fields :body`); after save it scans them and creates a `Mention`
per person, which is `Notifiable`: `Notifier.for` picks `Notifier::MentionNotifier`,
which skips self-mentions and creates a `Notification`. Notifications show in the
tray (`notifications/_tray`), which a bell in the bottom right corner fans open (`g n`), and on `/notifications`, and are emailed
(`NotificationMailer`). Opening one reads it and redirects to its record
(`notifications#show`). Client-facing editors never get the prompt.



## Documents

Files live in Active Storage (`storage/` locally). Two places, both Fizzy's:

- Inline in rich text: staff editors (`rich_text_field form, :body, staff: true`) take
  dropped, pasted or uploaded files through Lexxy's direct uploads, and `rich_text`
  renders them with Fizzy's `active_storage/blobs/_blob` partials. Client-facing editors
  stay text only (`attachments="false"`)
- A Documents section (`render "documents/section", subject:`) on clients, engagements,
  scope items, todos and requests: a `Document` per file (`Documentable`), with who
  uploaded it and a `client_visible` switch. Files are added from the quick action tray (Document), whose
  modal holds Fizzy's dashed `input--upload` drop target. The portal lists only
  client-visible files (`Engagement#client_documents`)

## Plugins

The core has no money or time; plugins add them. A plugin is a Rails engine gem: bundled ones
under `engines/`, named in the Gemfile (`gem "time_tracking", path: "engines/time_tracking"`);
installed ones under `plugins/` (gitignored), which the Gemfile globs and
`bin/rails "plugins:install[git url]"` fills (`plugins:update`, `plugins:remove`,
`plugins:list`; `docs/plugins.md`). It owns its tables (prefixed, e.g.
`time_tracking_entries`), points at core records by id, and never changes core tables. The
core never names a plugin; remove the gem and the app runs as before. Extension points
(`lib/runwell/plugins.rb`):

- View slots: `plugin_slots(:nav_actions)` (a button in the nav's foot, beside the theme toggle),
  `plugin_slots(:client_panel, client:)`, `plugin_slots(:engagement_panel, engagement:)`,
  `plugin_slots(:todo_panel, todo:)`, and in the portal `plugin_slots(:portal_home, client:)`
  and `plugin_slots(:portal_engagement_panel, engagement:)`;
  register with `Runwell::Plugins.slot name, key, partial`
- Nav: `Runwell::Plugins.nav key, label, -> { path }`
- Home: `Runwell::Plugins.briefing key, title, partial:, items: ->(user) { … }`
- Models: `ActiveSupport.on_load(:runwell_client | :runwell_engagement | :runwell_todo | :runwell_user) { has_many … }`
- Quick actions: `Runwell::Plugins.quick_action key, label:, icon:, partial:, types:, context:`
- Permissions: `Runwell::Plugins.permission key, :name, name:, roles:` (checked with `can?`)
- Portal: `Runwell::Plugins.portal_nav key, label, -> { path or nil }` (nil hides it). A
  plugin's portal pages inherit `Portal::BaseController`, so they only see the signed-in
  contact's client
- Settings: `Runwell::Plugins.settings key, label, -> { path }` gives the plugin a settings page,
  opened from the gear on its card in Settings > Plugins (a plugin without one gets a details page,
  `settings/plugins/:key`); its controller says `require_permission :manage_settings` and renders
  `settings/header` with `current: key`, which nests the page under Plugins in the Settings sidebar. Keys, tokens and
  secrets are `encrypts` columns shown with `secret_field form, :api_key`: masked, with an eye to
  reveal
- Nightly: `Runwell::Plugins.nightly key, -> { … }`, run by `PluginsNightlyJob`
  (`config/recurring.yml`); one plugin failing doesn't stop the others
- Stylesheets: `Runwell::Plugins.stylesheet key, "name"` from the engine's
  `app/assets/stylesheets`, linked while the plugin is on
- Events: every `Event` is published as `"event.runwell"` (`event:`)

Each plugin registers a manifest first:
`Runwell::Plugins.register :key, name:, version:, description:, author:, bundled:, enabled_by_default:, requires:, homepage:`
(`requires:` is a gem requirement on the core's `VERSION`; Settings > Plugins flags a mismatch).
Plugins are off until the owner switches them on in Settings > Plugins (state in
`Setting#plugin_states`), unless the manifest says `enabled_by_default: true`. Everything a
plugin registers is keyed by its key, and the core only renders registered things for
plugins that are on; a plugin's controllers and event subscribers check
`Runwell::Plugins.enabled?(key)` themselves. `time_tracking` is bundled and off by default.

Register in the engine's `config.to_prepare`; add routes to the app's route set from an
initializer (`app.routes.append { scope "time", module: "time_tracking", as: "time_tracking" … }`)
rather than mounting an isolated engine, so the core layout's helpers work on plugin pages.
Add migrations to the app's paths from an initializer. Changes to an engine's `engine.rb`
(registrations, initializers) need a server restart; they aren't reloaded. `engines/time_tracking` is the
reference: minutes logged on
clients, engagements and todos (a polymorphic `trackable`, like notes and documents, with the
engagement and client kept alongside so totals roll up), totals on engagements, a weekly timesheet, and "Log time" in the quick action tray.
No live timers.

## Quick actions

The tray at the bottom right (`A`, `quick_actions/_tray`) is Fizzy's tray. At the top of the
fan is a record picker (Fizzy's filter + combobox) set to the record on screen
(`current_record`) and able to pick any other; below it, one entry per action: Note and
Document in the core, plus any a plugin registers
(`Runwell::Plugins.quick_action key, label:, icon:, partial:, types:, title:, context:`). The
entries submit one GET form with the picked record, and the action's form opens in a modal
(`quick_actions#new`, loaded into the `quick_action` frame) with the same picker. This is
the only place notes, documents and time are added; a record's sections only list them.
The picker writes `record` ("Client:12") into the form through the `form` attribute; the
receiving controller reads it with `QuickAction.locate(params[:record], types)`. Forms post
with `data-turbo-frame="_top"` so the page redirects back as usual. The tray has no button on staff pages: `A` opens it
from the bottom right corner, above the notification bell.

## Clients and the portal

Clients are `Contact`s, never `User`s: no password, no staff role. Two switches per contact:
`portal_access` (sign in by emailed link, see the client's shared work and documents, send
requests) and `can_approve` (decide on agreements). `Contact#portal?` is checked on every
portal request, so switching access off or archiving a contact signs them out at once. What
a client sees is decided per record (`client_visible` on work and documents); there are no
client roles.

`engines/google_ads` is the reference for a plugin that reaches the portal: read-only Google
Ads reporting. The agency connects its own Google API app in Settings > Google Ads (OAuth,
credentials encrypted with Active Record encryption); an engagement links to an ad account
(`GoogleAds::Link`, permission `link_ad_accounts`); a nightly sync copies monthly and daily
figures; staff and the client see the same report (server-drawn SVG charts,
`GoogleAds::ReportsHelper`), and an account that stops serving shows on home and emails the
listed addresses. No management fee: the core has no money.

`engines/outsend` is the reference for a plugin that changes how the core does something
without a hook: a Mail interceptor routes each message through Outsend while the plugin is on
and has a key (Settings > Outsend, encrypted), so the core needs no mail extension point.
`engines/cloudflare` is the reference for a plugin with middleware and no tables: inserted
before `ActionDispatch::SSL`, it trusts `CF-Connecting-IP` only when the connection came from
a Cloudflare range (bundled list, refreshed nightly) and marks the request https.

`engines/coding` (Code) is the reference for a plugin that takes webhooks: git repositories
linked to clients, engagements and todos (`Coding::Repository`, a polymorphic `linkable`; a
todo inherits its engagement's repos and an engagement its client's). `checkout_work` hands an
agent the clone commands, branch (`p-4/58-slug`) and agreed scope; `log_progress`,
`finish_work` and `flag_out_of_scope` (a request to triage) report back. Connected to GitHub in
Settings > Code (OAuth), a signed public endpoint (`/code/github/webhooks`) brings in pull
requests and checks on work (a merge can mark the todo done), deploys (production ones on the
engagement timeline, and in the portal when shared), labelled issues as requests, and commits,
from which time is suggested when Time tracking is on. A deactivated person who can still reach
a linked repo shows on home. It never pushes code or stores secrets.

`engines/factory` (Factory) is the reference for a plugin that hands work to agents running
unattended. A person queues a todo (`Factory::Item`, with optional instructions) once it is ready
(`Factory::Readiness`: approved scope, a description or scope item, a linked repository from the
Code plugin, a client that allows it), or an approval queues its engagement's ready work
(`queue_on_approval`). A runner claims the next item with a lease (`claim_work`, earliest due first,
no priorities), renews it (`heartbeat_run`) and ends it (`finish_run`); a `Factory::Run` records the
runner, branch, pull request, summary and cost. Success puts the todo in review; failure frees it
for another attempt or blocks it once `max_attempts` are used; a lapsed lease abandons the run.
Limits live in `Factory::Policy` (runs at once, time, attempts, monthly budget, blocked clients).
What the agent is told is `Factory::Task`, served with each run. The runner is a separate Rust
binary in `engines/factory/runner` that talks only to `/mcp`; it never merges.

`engines/quickbooks` is where money lives, since the core holds none. A client links to a
QuickBooks customer by id (`Quickbooks::Customer`). A service links to a recurring invoice
template (`Quickbooks::RecurringLink`) that Runwell keeps in step: an approved revision
changes it and closing the service stops it (both from `"event.runwell"`, run in jobs), and
the nightly sync flags a template edited in QuickBooks so it no longer matches (`drift`).
Fixed-price work is invoiced from its panel (`Quickbooks::WorkOrderBilling`), in full or as a
deposit whose balance can be armed to send when the engagement is closed; QuickBooks emails
each with its pay link, and the portal lists open invoices with a Pay button. Every write to
the books is a named method on `Quickbooks::Api`. `engines/reporting` has no tables: it reads
the QuickBooks mirror (billed, collected, aging, by client, recurring coverage, approved but
not invoiced) and QuickBooks' profit and loss, for `view_financials`. A nav path lambda may
return nil to hide its link.

`engines/qa` (QA) is the reference for a plugin that adds a rule to a core model. A client's
checks (`Qa::Check`: an email, page, webhook or form) hold its source of truth as expectations
(`Qa::Expectation`: From address is exactly …, To is this list, the page shows the phone, never
shows another market's number, a promo line until its `expires_on`), each with a key fixed at
creation. A run (`Qa::Run`, immutable, results per expectation) comes from a person, an agent
(`record_qa_test`), the nightly page fetch (`Qa::PageFetch`, includes / excludes, phones matched in any
format) or the site itself posting to the check's public report URL (`/qa/report/:token`). A
check's state is derived from the latest result per expectation: failing, due (never tested,
older than `every_days`, or before a retest that a production deploy, a fix or a changed value asks for),
passing. A failed result opens a `Qa::Issue` (where, steps, expected, actual; found live when the
check is live, an escape); fixing it needs a root cause, and someone else or the next passing
test verifies it. A `Qa::Gate` puts a check on a todo: a validation added through
`:runwell_todo` keeps it from done until the check passes in tests since it last went to review,
by someone other than its owner (board drops that a rule refuses refresh the board with the reason).
`bin/rails "qa:import[engines/qa/examples/acme_storage.yml]"` loads a client's checks from a file.

`engines/account_management` (Account management) is the working system of whoever runs client
relationships, with its standard in `AccountManagement::Playbook` (hours ahead, targets). Each
client has one lead (`AccountManagement::Lead`). A meeting (`AccountManagement::Meeting`) holds
the agenda, due `AGENDA_AHEAD` before it starts, and the recap, due `RECAP_WITHIN` after; sending
either (emailed to contacts, or `via` another way) stamps the time for good, and its state is
derived (planned, agenda due, recap due, done, cancelled). Its action items are core commitments
(`add_action_item!`, linked by `MeetingItem`). The access register (`AccountManagement::Access`)
records a client's outside accounts (pages, ad accounts, pixels, analytics, domains): who owns
each, our access, where its login lives (never the secret), token expiry and when it was last
checked; `problems` says what's wrong. A lead's `WeeklyUpdate` is due by the end of Friday,
starts from a draft built from the week's records (`WeeklyUpdate::Draft`) and is final once sent.
`AccountManagement::Scorecard` counts only what's settled: agendas and recaps on time,
commitments done by their date (dropped ones don't count), updates by Friday, each with the
records that missed. Home (`Attention`) warns before a standard is missed.

## People and permissions

Three fixed roles (`User::Role`): owner (everything, including settings, plugins and
people), manager (sends agreements, records decisions, triages, closes, deletes) and member
(does the work). Each permission in `User::Role::PERMISSIONS` names the roles that have it;
plugins add theirs with `Runwell::Plugins.permission key, :name, name:, roles:`. No custom
roles or permission builder. Check with `user.can?(:delete_records)`, and in views `can?`.

- Every controller declares its rule, or its actions are refused before they run
  (`Authorization`): `allow_staff` for anyone signed in, plus
  `require_permission :close_engagements, only: :close`. An action with no rule raises
  `Authorization::MissingRule`. Public pages (`allow_unauthenticated_access`) skip it
- Rules about a record live on the model and are checked in the action
  (`Document#deletable_by?`: its uploader, or anyone who may delete records)
- Hide what someone can't do (`can?` around the button or form); the controller still
  enforces it. Nest ReActionView state reads inside the `can?` check, never in one chain
- People join by invitation (`Invitation`, Settings > People): an emailed, signed link
  that works once and expires in 7 days. Sign-up (`/signup`) only works while there are no
  users, and makes the first owner
- People are deactivated, never deleted (`deactivate!` ends their sessions; their name stays
  on their history). Pickers and mentions list `User.active.ordered`. The last active owner
  can't be demoted or deactivated

## Agents

Most use is expected to come through an AI harness, so anything the UI can do, an agent can
do, through the same controllers: there is no separate API.

- **Every action declares how an agent reaches it**, next to its authorization rule:
  `agent_tool :create_client, on: :create, title:, description:, params: { client: { name: "string!" } }`
  or `agent_exempt :preview, reason: "…"` (`AgentTools`). `new`/`edit` and public pages are
  exempt on their own. An undeclared action raises in development and test;
  `bin/rails agent:coverage` lists them all. Keep `params:` in step with the action's
  `params.expect` (types: string, text, integer, number, boolean, date, file, an array of
  values, a nested hash; `!` = required; path params come from the route)
- **Reads** need a `.json.jbuilder` view beside the HTML one. Start each record with
  `json.merge! agent_ref(record)` (type, id, `record` "Type:id", display name, `url`) and give
  every view a `summary`. Rich text goes out through `agent_text`
- **Writes need nothing extra**: `AgentResponses` turns the redirect + notice into
  `{ status: "ok", summary }`, a redirect with an alert or a 422 re-render into
  `{ status: "error", errors }` (from the record the action was saving). So write notices a
  model can act on, and give `redirect_back` a sensible fallback
- **Anything that reaches a client** (sends, emails, portal visibility) declares `confirm:`;
  the tool then answers `needs_confirmation` with a preview until called with `confirm: true`
- A tool runs the real action with the caller's token (`Agent::Dispatch`), so roles,
  permissions, validations and events are the UI's. `Agent::Catalogue.for(user)` offers only
  what their role and switched-on plugins allow; `me` explains what's withheld
- Every person has an agent user (`User::Agent`: `agent_owner_id`, "Ted's agent", made on
  creation or first use). A bearer token belongs to its person but its requests run as that
  person's agent (`Current.user`), so writes read "Ted's agent via Claude": the agent has its
  person's permissions exactly (`can?` delegates), can't sign in, and is kept out of pickers and
  mentions (`User.people`). Agent writes carry `Current.source = "agent"` and the app's name as
  the event's actor label. Model verbs default `source:` to `Current.source`, never `"app"`
- The AI button on work (`todos/_ai_brief`, key `c`) copies `Todo::Brief` from
  `/todos/:id/brief` (also the `brief_work` tool): the work, agreed scope, notes, commitments and
  the `runwell` commands to report back. Plugins add sections with
  `Runwell::Plugins.agent_brief key, ->(todo, base_url) { markdown }` (Code adds repos and a branch)
- Auth: `AccessToken` (personal from Settings > Connected apps, or OAuth), digests only.
  OAuth 2.1: discovery at `/.well-known/oauth-*`, dynamic registration, PKCE (S256), consent at
  `/oauth/authorization`, hourly tokens with refresh, revocation. `/mcp` takes bearer tokens
  only, never a session cookie. Agents can't mint or revoke tokens
- Plugins declare tools in their controllers the same way; they appear while the plugin is on
- The CLI has no per-tool code: every command is a tool from `tools/list`. Don't add
  commands to it for app features; declare a tool instead. Its own commands are only about the
  CLI: `login` (`--read-only`), `doctor` (`--brief` is the Claude Code SessionStart check),
  `update`, `mcp` (`--read-only`), `agent setup` (a managed skill, marked, refreshed by `update`,
  never overwriting a hand-edited one). Output is JSON when piped; `--ids-only`, `--count`,
  `--field a.b` trim it. Exit statuses follow the error codes (`runwell help exit-codes`)
- **Errors are machine-readable**: every agent error carries a `code` (usage, not_found, auth,
  forbidden, refused, invalid, read_only, failed) and a `hint` (`Agent::Errors`); a redirect with
  an alert is `refused`, a 422 is `invalid`. A success whose tool declares `next_tools` also
  carries `next`: runwell commands with the ids from the call or its answer filled in
- **Read-only access**: a token (personal, or OAuth with scope `runwell:read` / the consent
  checkbox) may be read-only. It is offered only GET tools and any non-GET request with it is
  refused with `read_only` (`ApplicationController#refuse_read_only_writes`)

## Custom fields

What an install records about clients, engagements and work beyond the core (a plumber's
property address, a firm's matter number, an agency's website) is a custom field, not a
column: the core only holds what every business needs. Defined in Settings > Fields
(`CustomField`: model, label, a key fixed at creation, kind, choices, `listed` as a table
column, `client_visible` in the portal); values live in `CustomValue` as text (money in
cents, dates ISO) and are set by key, `record.update(custom_fields: { "renewal" => "2026-12-01" })`,
which the create and update tools take as `custom_fields: {}`. The `CustomFields` concern checks
each value against its kind, and search indexes them. Forms render them with
`custom_field_inputs form, record` (a helper, since partials can't render in `form_with`);
pages with `render "custom_fields/values", record:`. Rules: information only, nothing acts on
a custom field; never required; a kind can't change once it has values; archiving keeps
values; a plugin keeps its own data in its own tables, never in a custom field.

## Releases and updates

Every install is its own copy, so a change reaches an install only when it updates. This
repository is public (FSL-1.1-MIT, `LICENSE.md`). A release is a `vX.Y.Z` tag made by
`bin/release 2.1.0` (writes `VERSION`, commits, tags, pushes); `.github/workflows/release.yml`
publishes it. Nothing that names a deployment or a client is tracked (`config/deploy*.yml`,
`.kamal/secrets*` and QA source files are ignored): everything committed is public. `Release` is the newest one GitHub lists, checked
nightly (`ReleaseCheckJob`) and by Check now, kept on `Setting#latest_release`. Owners see it on
home (`briefings/_update`) and in Settings > Updates, whose button makes an `Upgrade`: `in_place`
(any Docker install) downloads the release's bundle into the data volume and restarts on it,
like WordPress (`Upgrade::InPlace`, run by `bin/docker-entrypoint`), `local`
runs `bin/update <tag>` in the background (`Upgrade::Local`), `github` starts
`.github/workflows/deploy.yml` for the install's Kamal destination (`Upgrade::Github`), `manual`
shows the command. An upgrade succeeds when the install boots on the new version, and fails when
its run fails or goes quiet (`Upgrade#reconcile!`). See `docs/install.md`.

In production `db:migrate` and `db:prepare` back up every database with pending migrations
first (`lib/tasks/backup.rake`). Updates run unattended, so **every migration must be safe on a
live install**: add columns and tables in one release; remove or rename them only in a later
release, once no code reads them. No migration may depend on a person running a task by hand.

## Settings and names

Settings (the gear, `/settings`) has Appearance, Names, Fields, Views, Email, Plugins and Updates (`manage_settings`), People (`manage_people`), and Connected apps and Help for everyone. They're listed in a grouped sidebar (`settings/_nav`, `settings-nav.css`), each plugin's settings page nested under Plugins. A settings page starts with `render "settings/header", current: :key`, which sets the header's title and hands the sidebar to the application layout (`content_for :settings_nav`); pages add no navigation of their own. Names are core: the words for
client, engagement, scope item and work, and each engagement type's name, plural, ref
prefix and whether it's used. Defaults live in `config/locales/terms.en.yml`; overrides in
`Setting#terminology` (one row, single tenant). In views use `term(:engagement)`,
`term(:engagement, count: 2)`, `label_term(label)` and `label_options(current)` — never
hard-code "Engagement", "Project", "Client" or "Work". Keys (`project`, `work_order`,
`service`) never change. A new prefix applies to new refs only.

## Appearance

Settings > Appearance sets the install's default theme (system, light, dark), color
scheme, corners and font, plus a logo and favicon (Active Storage on `Setting`). Each
layout's `<html>` carries them as `data-scheme`, `data-radius`, `data-font` and
`data-default-theme` (`appearance_data`); `appearance.css` turns them into Fizzy's tokens,
and the page previews a change instantly (`appearance` controller) before saving.
A person's sun/moon choice (localStorage) beats the install's default theme.

Every border radius in the stylesheets goes through two variables so Corners reaches the
whole UI: ordinary corners are `calc(<size> * var(--radius-scale, 1))`, pill shapes are
`var(--radius-pill, 99rem)`, true circles stay `50%`, and every control (buttons, inputs,
selects, toggles, tags) uses `var(--radius-control)` so they always match. Write new CSS
the same way.
Schemes and fonts override Fizzy's unlayered tokens, so they are unlayered too.

