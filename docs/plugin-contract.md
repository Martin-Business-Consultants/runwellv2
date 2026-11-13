# The plugin contract

Everything a plugin may rely on from the core, with the core version it arrived in. A plugin's
manifest says which cores it works with (`requires: ">= 2.12"`), and Settings › Plugins flags one
that needs a newer core. How to build, develop and release a plugin is in
[plugins.md](plugins.md); the
[plugin template](https://github.com/Martin-Business-Consultants/runwell-plugin-template) is a
working starting point.

**Stable** means it keeps its name, arguments and meaning within the major version (4.x): a change
that would break a plugin waits for 5.0, and anything going away is marked deprecated first, for at
least one minor release. **Experimental** may change in a minor release, said in its release
notes.

What is *not* in the contract: core class names other than those below, core tables and columns
(read them through the models; never write to them directly), view markup and CSS classes, private
methods, and anything under `Agent::`, `Upgrade`, `PluginChange` or `Setting`'s internals.

## Rules a plugin keeps

- It owns its tables, prefixed with its key (`time_tracking_entries`), pointing at core records by
  id. It never adds columns to, or writes rows in, core tables except through the core's own model
  verbs (`task.update(status: …)`, `client.record_event!(…)`).
- It registers everything in its engine's `config.to_prepare`, keyed by its key, and its
  controllers and subscribers check `Runwell::Plugins.enabled?(key)`. The core renders a plugin's
  registrations only while it's on.
- Its controllers declare an authorization rule and an agent tool (or `agent_exempt`) per action,
  as the core's do. Its migrations are safe on a live install.
- Removing it leaves the core working: nothing in the core names a plugin.
- It uses only the gems the core bundles (it is loaded outside Bundler). Among them for plugins: `ruby_llm` (AI providers) and, since 3.0, `prawn` (PDFs).
- Its JavaScript is its own, in `app/javascript/<key>/` (see Plugin JavaScript): it never patches,
  replaces or reaches into the core's controllers, and the core's markup and CSS classes are not
  an API to script against.

## Manifest

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.register key, name:, version:, description:, author:, enabled_by_default:, requires:, homepage:` | 2.0 | Stable |

`requires:` is a gem requirement on the core's `VERSION`. `enabled_by_default:` is accepted and
ignored since 5.0: every plugin starts off until an owner switches it on.

## Views

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.slot name, key, partial` | 2.0 | Stable |
| `Runwell::Plugins.nav key, label, -> { path or nil }, icon: "globe"` | 2.0 (`icon:` 2.25) | Stable |
| `Runwell::Plugins.stylesheet key, "name"` | 2.0 | Stable |
| `Runwell::Plugins.quick_action key, label:, icon:, partial:, types:, title:, context:` | 2.0 | Stable |
| `Runwell::Plugins.settings key, label, -> { path }` | 2.0 | Stable |
| `Runwell::Plugins.shortcut key, "i", "What it does"` | 2.18 | Stable |

Slots, and the locals each partial gets:

| Slot | Where | Locals | Since |
| --- | --- | --- | --- |
| `:client_panel` | A tab on each client | `client:` | 2.0 |
| `:work_panel` | A tab on each work | `work:` | 2.0 |
| `:task_panel` | A tab on each task | `task:` | 2.0 |
| `:nav_actions` | A button in the nav's foot | none | 2.0 |
| `:portal_home` | The client portal's home: a card in its sidebar, under any dashboard (below the work until 5.32) | `client:` | 2.0 |
| `:portal_work_panel` | A piece of work in the portal | `work:` | 2.0 |
| `:email_inbound` | Settings › Email, how requests' mail comes in | none | 2.5 |
| `:client_aside` | A client's sidebar, above Details | `client:` | 2.18 |
| `:work_aside` | A piece of work's sidebar, under its sections and details | `work:` | 3.0 |
| `:work_meta` | The line under a piece of work's title: a status badge or a short fact (an inline element) | `work:` | 3.0 |
| `:task_aside` | A task's sidebar, above Details (requests are tasks, so this replaces `:request_aside`) | `task:` | 3.0 |
| `:scope_item_aside` | A section's (scope item's) sidebar, above Details | `scope_item:` | 2.18 |
| `:note_row` | Inside each note in a Notes section | `note:` | 2.18 |
| `:portal_actions` | The portal header's buttons | `contact:` | 2.18 |
| `:portal_dashboard` | The sidebar of the portal's first page, beside the client's work (under it on a narrow screen): a dashboard for the client (what's new, what's coming up). The core draws none; each partial is a card or several, stacked down the sidebar (5.29 to 5.31 drew them above the work; the sidebar since 5.32). `Task.unread_discussion_ids(contact)` gives the shared tasks holding a message the contact hasn't read, `task.client_status` what a client reads for a status, `portal_task_link_to(task)` a link opening it in the portal's side sheet | `client:`, `contact:` | 5.29 |
| `:portal_task` | A shared task's side sheet in the portal, under its description and above its files and discussion: something for the client to decide or do on it. Redrawn whenever the sheet is (a reply, a live refresh) | `task:`, `contact:` | 5.31 |
| `:task_notice` | Under a task's title, on its page and in its side panel: a short note (render nothing when there's nothing to say) | `task:` | 5.6 |

**Removed in 3.0:** `:request_aside` and `:commitment_row`, with the `Commitment` and `Request`
models: commitments and requests became tasks (see Models). A plugin that filled `:request_aside`
fills `:task_aside` instead (`task.request?` says whether nobody has taken it on yet). Also
`:approval_page` and `:draft_version`, with agreements, which left the core for the Agreements
plugin: a piece of work's own tab is `:work_panel`, its sidebar `:work_aside` and its
title line `:work_meta`.

**Peeks render no slots (since 5.22).** A client, a piece of work or a contact opened in the side
panel (`?peek=Work:12`) shows its title, fields, open tasks and notes, and an Open button to its
page. The `*_aside`, `*_panel` and `:work_meta` slots stay on the record's own page: they were made
for its sidebar and tabs, and a narrow panel over another page is no place for them. A note's
`:note_row` still shows in a peek's notes, as it does everywhere notes do.

A slot partial declares strict locals on its first line, like every core partial. The row slot
(`:note_row`) renders once per row: tasks out anything shared once a request (a
`CurrentAttributes` of the plugin's own), never a query per row. A shortcut only lists a key on the
`?` sheet; the plugin's control declares it with `data-keys`, which is what makes it tasks. A nav or
settings path lambda runs in the view and may return nil to hide the link. Where a plugin's link
sits is the install's (Settings › Sidebar, 5.7: among the core's pages, in a section an owner names,
or hidden), and each person can hide it for themselves (Settings › Your account), so a plugin can't
count on its place in the nav or on a particular `g` number. A settings page's
controller says `require_permission :manage_settings` and starts its view with
`render "settings/header", current: key`.

Helpers a plugin's views may use: `document_drop_target(form, class)` and `document_upload_data` (5.12: the dashed drop box and the
upload controller's data for a `form_with` that posts `document[files][]`, each file sent straight to storage first),
`document_preview_kind(document)` (5.12), `term`, `label_term`, `person_tag`, `status_tag`, `rich_text`,
`side_panel_link_to` (`task, content = nil, **options` or a block: a link that opens the task over the
page in the side panel, its href the task's own page for a new tab; 5.5, stable),
`rich_text_field`, `date_input`, `money`, `money_field`, `secret_field`, `code_block`, `icon_tag`,
`can?`, `current_record` (the record on screen, or nil; 2.18), `section_nav`, `section_nav_heading`
and `section_nav_link` (2.21), `popup_menu` (`label:`, `title:`, `fixed:`, a block: the popup a
pill or badge opens below itself; 3.0), `switch_field` (`form, :attr, label:, hint:,
submit_on_change:`) and `switch_tag` (`title:`, `screen_reader_label:`, a block holding any
checkbox) for on/off switches (3.0), and the shared partials `layouts/shared/empty` (`text:`,
`action_text:`, `action_path:`; an empty list's line; 3.0), `layouts/shared/card`, `delete_dialog`, `confirm`, `row_actions`,
`quick_filter` and `index_toolbar` (2.0, stable), and `notes/section` (`subject:`, any record with notes:
the composer and its notes, posting to the full page and back; `permanent: false` on a page that
swaps one record's notes for another's in place; documented in 2.25.2, stable), and
`tasks/owner_picker` (`task:`, `labelled:`; who's on a task, changed in place: since 2.22,
documented in 2.25.4, stable), and `tasks/ai_brief` (`task:`, `labelled:`; copies the task's brief for a
local AI, `c` on a keyboard item: documented in 2.28, stable). The brief itself is
`Task::Brief.new(task, base_url:, person:).to_s` (Markdown: the tasks, scope, notes, other dated tasks,
plugins' sections and the `runwell` commands to report back; documented in 2.28, stable). Design tokens for its CSS are in
[theming.md](theming.md) (2.12; shadcn's and runeui's since 6.0).

Any other core helper is not part of this contract and may go without notice. Two plugins used
were removed in 3.0 with agreements: `contact_options` and `default_approver`; keep a copy in the
plugin (QuickBooks has `quickbooks_contact_options` and `quickbooks_default_contact`).

**The UI kit (6.0).** A plugin's views are drawn with runeui, the core's UI kit (`../runeui`; its
README lists every component): `ui :name` (`ui :button`, `ui :badge`, `ui :card`, `ui :table`,
`ui :menu`, `ui :dialog`, `ui :alert`, `ui :empty`…) and `form.ui :field` inside `form_with`, with
`icon_tag` for the core's icons by name. A plugin's stylesheet reads runeui's tokens, which are
shadcn's (`--background`, `--foreground`, `--primary` for the brand's colour, `--muted-foreground`,
`--border`, `--destructive`, runeui's `--ui-*` scale…), plus the core's `--faint-foreground`,
`--brand-tint` and `--brand-tint-strong`: [theming.md](theming.md) lists them. Runwell's own
classes (an area's `record-page`, `settings-section`, `task-group`…) are still not an API.

**The compatibility layer (6.0 until 7.0).** What plugins drew with rune_ui before 6.0 keeps
working, drawn by runeui in the install's theme, and goes in 7.0, so a plugin moves off it before
then:

- The helpers (`RuneCompatHelper`): `button_link`, `action_button`, `submit_button`,
  `icon_button`, `button_classes` (variants `:primary`, `:secondary`, `:ghost`, `:danger`; size
  `:sm`), `badge`, `card`, `list_row`, `field`, `form_errors`, `empty_state`, `menu`,
  `popover_menu`, `menu_link`, `menu_button`, `menu_label`, `menu_divider`, `dialog`, `sheet`,
  `dialog_actions`, `confirm_dialog`, `tabs`, `callout`, `avatar`, `avatar_stack`,
  `settings_group`, `setting_row`, `switch_tag`, `copy_button`, `copy_field`, `progress_bar`,
  `status_dot`, `time_ago`, `crumbs`, `flash_messages`, and `popup_menu` (`PopupHelper`, with the
  `dialog` controller); the Stimulus controllers `rune-clipboard` and `rune-local-time`.
- The classes (`runwell/compat.css`): `btn` (`--primary`, `--secondary`, `--ghost`, `--danger`,
  `--sm`, `--accent`), `icon-button`, `pill`, `card` and its parts (`__head`, `__title`, `__hint`,
  `__action`, `__content`, `__footer`; `--flush`, `--sm`), `list-row` and its parts, `field`,
  `field__label`, `field__hint`, `field-row`, `badge` and its tones, `count`, `chip`, `kbd`,
  `separator`, `tabs` / `tabs__tab` (`--pills`, `--icons`), `alert` (`--danger`), `table` in a
  `table-wrap` (`table__grow`, `number`), `data-table`, `dl.details`, `empty`, `stack`, `grid-2`,
  `catalog`, `dot-list`, `button-row`, `page-header`, `menu`, `popover-menu`, `popup` and its
  parts, `switch`, `checkbox`, `search`, `copy-field`, `status--*`, `letter`, `avatar`, `skeleton`,
  `crumbs`, `muted`, `faint`, `small`, `nowrap`, `visually-hidden`, `[data-tooltip]`; and bare
  inputs, selects, textareas, headings, links and forms (a flex column) styled as rune_ui did.
  Classes nothing used in 5.x's plugins went in 6.0: `card--danger`, `card--fold`, `fold`,
  `list-row--tall`, `list-row--outline`, `field--inline`, `icon-button--danger`, `alert--attention`,
  `dialog__body`, `menu__*`, `prose`, `table--even`, `table__cap`, `crumbs__sep`, `crumbs__current`.
- The token names, each defined from runeui's (so they follow every scheme, corner, font and
  custom theme):

  | Old name | 6.0 reads it as |
  | --- | --- |
  | `--panel`, `--page` | `--background`, `--sidebar` |
  | `--layer-1`, `--layer-2`, `--layer-3` | `--muted` halfway into `--background`, `--muted`, `--muted` a step darker |
  | `--text`, `--text-muted`, `--text-faint` | `--foreground`, `--muted-foreground`, `--faint-foreground` |
  | `--line`, `--line-strong`, `--hover` | `--border`, `--input`, `--foreground` at 4% (8% in dark) |
  | `--accent` (the brand), `--accent-ink`, `--accent-hover`, `--accent-soft` | `--primary` (see below), `--primary-foreground`, `--primary` 90% into `--background`, `--brand-tint` |
  | `--ring` (the focus shadow) | `--ui-focus-ring` (see below) |
  | `--ok`, `--danger`, `--attention` | `--success`, `--destructive`, `--warning` |
  | `--s-1` … `--s-6` | `0.25rem` … `2rem` |
  | `--radius-sm`, `--radius-md` / `--radius-control`, `--radius-lg` / `--radius-panel`, `--radius-xs`, `--radius-pill` | `--ui-radius-sm`, `--ui-radius-md`, `--ui-radius-xl`, `--radius` − 6px, `--ui-radius-full` |
  | `--radius-scale` | Corners as a number: 0.4 (Sharp), 1, 1.6 (Round) |
  | `--control-h`, `--control-h-sm`, `--row-h` | `--ui-h`, `--ui-h-sm`, `2.5rem` |
  | `--text-xs` / `--text-meta`, `--text-ui` / `--text-read`, `--text-title` | `--ui-text-xs`, `--ui-text-sm`, `1.25rem` |
  | `--weight`, `--weight-strong`, `--leading`, `--leading-tight` | `400`, `500`, `1.25rem`, `1rem` |
  | `--shadow-popover`, `--motion*`, `--ease` | a hairline and `--ui-shadow-lg`; as before |
  | Fizzy's `--color-ink*`, `--color-canvas`, `--color-link`, `--color-positive`, `--color-negative`, `--color-selected*`, `--focus-ring-color`, `--inline-space*`, `--block-space*`, `--text-x-small` … `--text-xx-large` | `--foreground` … `--border`, `--background`, `--primary`, `--success`, `--destructive`, the brand tints, `--ring` at half, as before |

  Two names are runeui's own now and mean what shadcn means: `--accent` is the quiet hover fill and
  `--ring` a colour. So that a plugin's stylesheet keeps its look, the core reads its
  `var(--accent)` as `var(--primary)` and its `var(--ring)` as `var(--ui-focus-ring)` as it serves
  the sheet (`lib/rails_ext/propshaft_plugin_stylesheets.rb`, for stylesheets registered with
  `Runwell::Plugins.stylesheet`). Moving to runeui's names, a plugin writes `--primary` for the
  brand's colour and `--ui-focus-ring` for focus, and from then on `--accent` and `--ring` mean
  shadcn's.

A plugin with several pages of its own lists them in a sidebar beside the page, as Settings does:
each page calls `section_nav "Its name" do … end` once (a partial of the plugin's, given the
current page), with `section_nav_heading` over each group and
`section_nav_link label, path, icon:, current:` for each page. Below 960px it runs across the top.
The page itself then needs no links to its siblings. Since 2.21, stable.

**Removed in 3.0** (deprecated in 2.29): the core's `repeater` controller. A plugin that repeats
rows ships its own (Websites' `website-checklist--repeater` is a working copy to start from).

A drop box for files is the core's `upload` Stimulus controller on a multipart form
(`data-upload-url-value` the direct uploads URL, `data-upload-max-size-value` `Document::MAX_SIZE`),
around the dashed drop target, `document_drop_target(form)` (4.0: a `label.upload-drop` holding a
`data-upload-target="status"` text, a hidden `<progress data-upload-target="progress">` and a
multiple file input, `data-upload-target="input"`, `data-action="change->upload#start"`; its
fields post as `document[files][]`). Dropped or chosen files go
straight to storage, then the form posts their signed ids under the input's name; check each
blob's size on the server too. Documented in 2.24.0, stable.

Picking rows to act on together is the core's `bulk` Stimulus controller, already on every staff
page's `<main>`: a checkbox per row with `value` the record's id, `data-bulk-target="item"` and
`data-action="bulk#update"` (add `data-keys="x"` inside a keyboard item, so `x` picks the row
you're on), and the bar, from `BulkHelper`: `bulk_bar(delete:) { … }` around `bulk_menu`,
`bulk_button`, `bulk_date` and `bulk_delete`. (`bulk_copy`, added in 2.28, is **removed in 3.0**:
copying is a plugin's own controller, reading the picked boxes,
`[data-bulk-target~='item']:checked`; My day's `my-day--copy-prompt` does it.) The bar shows while anything is picked, and each of
its forms is sent with the picked ids as `ids[]`. For tasks, the core's own `bulk_tasks_path`
(PATCH `task[status]`, `task[owner_id]`, `task[due_on]`, `task[client_visible]`; DELETE) runs each
task's verbs and redirects back. Documented in 2.25.4, stable.

Since 6.0 the core's own lists are runeui's (`ui :table` with `ui :select_cell`, `ui :filter`,
`ui :empty`; `docs/runeui-migration.md`), and the names above are kept for plugins, drawn with
runeui, with the same locals and params: `layouts/shared/quick_filter` (a labelled pill now,
"Owner: Anyone", with a search box past eight choices; picking one adds a history entry, so Back
undoes it), `index_toolbar`, `row_actions`, `empty`, the `bulk_*` helpers (the bar is
`ui :bulk_bar`; `bulk_menu` opens a `ui :menu`) and `bulk_select_all_header` / `bulk_select_cell`
(still native checkboxes for the `bulk` controller). The data table's own classes
(`data-table__*`, `quick-filter`, `bulk-bar__*`) were never the contract and are gone; `.table`,
`.table-wrap` and `.table__grow` stay.

Dragging items between lists is the core's `drag-and-drop` Stimulus controller (the Tasks board's):
on a wrapper, `data-controller="drag-and-drop"` with
`data-drag-and-drop-dragged-item-class` (`drag-and-drop__dragged-item`) and
`data-drag-and-drop-hover-container-class` (`drag-and-drop__hover-container`), and
`data-action="dragstart->drag-and-drop#dragStart dragover->drag-and-drop#dragOver
drop->drag-and-drop#drop dragend->drag-and-drop#dragEnd"`. Each draggable element is
`draggable="true"` with `data-drag-and-drop-target="item"` and `data-id`. Each list it can be
dropped on is `data-drag-and-drop-target="container"` with `data-drag-and-drop-url` (its `__id__`
becomes the item's id) and, inside, a `data-drag-drop-item-container` the item is moved into. A
drop POSTs to that URL asking for a turbo stream; a container marked `data-drag-and-drop-sortable`
also takes drops within itself and sends `before` (the id of the item it now sits before, blank at
the end). Documented in 2.25.2, stable.

## Plugin JavaScript

| What | Since | Status |
| --- | --- | --- |
| `app/javascript/<key>/controllers/*_controller.js`: Stimulus controllers, loaded on every page | 2.29 | Stable |
| `app/javascript/<key>/**/*.js`: modules, imported as `"<key>/…"` | 2.29 | Stable |
| Importing `@hotwired/stimulus`, `@hotwired/turbo-rails`, `@rails/request.js` | 2.29 | Stable |
| The core controllers listed below, used from a plugin's markup | 2.29 | Stable |

A plugin ships its own JavaScript, in `app/javascript/<key>/` (its key, with underscores). The
core pins that folder in the import map under the key (`config/importmap_plugins.rb`), serves it as
assets (compiled on boot in production, like its stylesheets), and registers everything in
`controllers/` with Stimulus under the key: `app/javascript/my_day/controllers/copy_prompt_controller.js`
is `data-controller="my-day--copy-prompt"`. Nothing to register, and no way to name a controller
outside the plugin's key, so two plugins, or a plugin and the core, can't collide.

A plugin's `form.select` (or `combobox_tag { select_tag … }`) is the core's select, like every
select: runeui's `ui :select` for a short list, and past seven choices, for several (`multiple`)
or with `search: true`, a combobox behind a button with a box to search its choices (6.0; from
5.7.2 to 5.x every select had the box; `data: { combobox_filter: "always" }` still asks for it).
`class: "select--sm"` makes it the small kind, for a row of filters. The form builder's
`text_field` and its kin, `text_area` and `check_box` draw runeui's controls too (6.0), and
`date_input`, `money_field`, `secret_field` and `switch_field` keep their signatures. The
`quick_filter` partial (same locals as ever) draws that combobox since 5.7.2, in a GET form of its
own, instead of a pill and menu of links.

What a plugin's JavaScript may lean on: the three packages in the table (pinned by the core, kept
across 2.x), its own modules, and these core controllers from its markup, with the data attributes
their own pages use: `form` (`submit`, `debouncedSubmit`, `cancel`, `form-target="submit"`),
`dialog` (`open`, `close`, `toggle`, `dialog-target="dialog"`), `poll` (`poll-interval-value`: reloads
the nearest turbo frame), `copy-to-clipboard` (`content` or `url` value, `success` class), `upload`,
`drag-and-drop` and `bulk` (above), `pagination` (a list that loads its next page as you scroll:
`paginate(records)` in the controller, `with_automatic_pagination` around a cards grid, or
`pagination_frame_id_for` and `table_next_page_row` with `data-controller="pagination"` on a table,
as the core's indexes do), `date_input` (a `ui :date_picker` since 6.0; the `date-field`
controller is gone), and the keyboard's
`data-keys` and `data-filter-target="item"` (Keyboard shortcuts in the core's AGENTS.md). Anything
else of the core's (its other controllers, helpers in `app/javascript/helpers`, `window` globals,
markup and class names) is not the contract and may change in a minor release.

Good practice, because people will run your plugin on installs you'll never see:

- One job per controller, small, named for what it does, with a comment saying so and what it reads.
  Do in the browser only what has to happen there; the rest stays on the server, so agents (which
  never run JavaScript) can do everything a person can.
- Tasks without it where you can: a form that still submits, a link that still goes somewhere.
- Listen on the controller's own element, not `document` or `window`; if you must (a `turbo:morph`),
  remove the listener in `disconnect()`. Never `preventDefault` an event the core handles.
- Turbo morphs pages in place: build what you add from server markup where you can, and expect
  `connect()` / `disconnect()` to run again.
- No inline `<script>`, no `eval`, no third-party CDNs. A library goes in `app/javascript/<key>/vendor/`
  (its license with it) and is imported as `"<key>/vendor/…"`.
- Nothing secret in the browser: keys and tokens stay on the server.
- A plugin whose JavaScript needs 2.29 says `requires: ">= 2.29.0"`; on an older core it isn't loaded.

## Permissions and the nightly run

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.permission key, :name, name:, roles:` | 2.0 | Stable |
| `Runwell::Plugins.nightly key, -> { … }` | 2.0 | Stable |

`roles:` is any of `owner`, `manager`, `member`. Check a permission with `user.can?(:name)` or `can?`
in views. A nightly task should enqueue a job rather than do slow tasks itself; one plugin failing
doesn't stop the others.

## Models

| Hook | Since | Status |
| --- | --- | --- |
| `ActiveSupport.on_load(:runwell_client) { has_many … }` | 2.0 | Stable |
| `ActiveSupport.on_load(:runwell_work) { … }` | 2.0 | Stable |
| `ActiveSupport.on_load(:runwell_task) { … }` | 2.0 | Stable |
| `ActiveSupport.on_load(:runwell_user) { … }` | 2.0 | Stable |
| `ActiveSupport.on_load(:runwell_document) { … }`: rules on a `Document` (a validation refusing `client_visible` is shown in words wherever the switch is flipped) | 5.12 | Stable |

Add associations, scopes and validations there; never columns. Core models a plugin may read and
call verbs on: `Client`, `Contact`, `Work`, `ScopeItem`, `Task`, `Note`, `Document`, `Event`, `User` (2.0, stable), and
`Setting.current.record_event!` for a settings change worth the audit log (2.18, stable).

Work types (5.9, stable): an install's kinds of work are records (`WorkType`, Settings > Names >
Types), no longer a fixed list. A piece of work keeps its type's key in `work.label`, as before;
`Work.labels` is every type's key (archived ones too), `WorkType.cached` every type in the
install's order (`key`, `name_one`, `name_other`, `prefix`, `shape`, `cadence`, `archived?`,
`system?`), `WorkType.active_keys` those offered for new work, and `work.work_type` its type.
Project, work order and service are always there (`WorkType::SYSTEM_KEYS`), though an install can
switch them off. `Work::LABELS` still holds those three and is deprecated: it goes in the next major version (6.0), so read
`Work.labels` (or `WorkType.cached`) instead, falling back to `Work::LABELS` on an older core. Keys
never change; a type merged into another moves its work (`work.retyped`) and is deleted. A piece of
work also has `cadence` (how often recurring work comes round, `Cadence::KEYS`), and a task `repeat`
(the same keys: marking it done makes the next one, `Task::Repeats`). Works, scope items and tasks
have `client_priority` (5.10): the client's own order, set in the portal (`ClientPrioritized`,
`by_client_priority`, `in_client_order`), nil until they order them.

Custom fields (5.5, stable): `record.custom_field_hash` (key → typed value, only the fields the
person may see) and `CustomField.dates_between(range, viewer: Current.user)`, every date field's
value inside a range of dates as `[record, field, date]` (the record a `Client`, `Work` or `Task`;
`field.label`, `field.key`), leaving out fields the viewer may not see. Never read `CustomValue`
directly: it ignores who may see a field. With `client:` (5.6) it's what that client sees in the
portal instead: fields shown to clients, on the client, its work and the tasks shared with it.

## Calendars

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.dates key, ->(range, viewer) { [ Runwell::Plugins::Dated.new(date:, title:, label:, path:, people:) ] }` | 5.6 | Experimental |
| `Runwell::Plugins.dates_between(range, viewer:)` | 5.6 | Experimental |

A plugin with dated things of its own (a deadline, a booking, a renewal it keeps) offers them to
calendars: its source gets a range of dates and the viewer (a `User`) and returns what that person
may see in it. `label` says what kind it is ("Booking"), `path` where it opens (or nil), `people`
the Users it's about, so a calendar can filter by person and flag someone who's out.
`dates_between` gathers every switched-on plugin's, each marked with its `plugin` key, dropping
anything outside the range; a source that raises is reported and left out. It names no client or
work, so a calendar filtered to one leaves these out, and its search matches their title by the
text it contains.

| `Runwell::Plugins.away key, ->(range) { { user_id => [dates], everyone: [dates] } }` | 5.8 | Experimental |
| `Runwell::Plugins.away_between(range)` | 5.8 | Experimental |

Who's away on which days (time off, a holiday for `everyone`), for pickers that put people on
things: the task owner picker marks someone "Out" on the task's due date. `away_between` merges
every switched-on plugin's into `{ user_id => Set of dates, everyone: Set }`; a source that raises
is reported and left out.

## Search

| Call | Since | Status |
| --- | --- | --- |
| `Search.new(terms).results`, `Search.new(terms).people` | 5.5 | Experimental |

The core's search, as the search palette uses it: `results` is up to 50 clients, works, tasks and the
rest, ranked, matching each typed word exactly, by its start ("acm" finds Acme) or within a typo or
two ("clinet"); `people` is the team whose name or address contains what was typed. Pass
`fuzzy: false` for exact matches only. The index catches up a moment after a save.

**Changed in 3.0:** `Commitment` and `Request` are gone; both are tasks. A task may sit straight on
a client: `task.work` can be nil, and `task.client` (a column now, `client_id`) is the one
to read, nil only for an email from an unmatched sender. A request is a task nobody has taken on
or started, `Task.requests` (`task.request?`), with who asked (`task.contact`, `sender_name`,
`sender_email`, `requester_name`) and how (`task.source`). A promise is a task with a due date,
owned by whoever it's assigned to.

**Changed in 3.0, agreements:** `AgreementVersion`, `Approval` and `ApprovalLink` are gone from the
core, with sending, snapshots, client decisions and approval links (the Agreements plugin keeps its
own). Their tables (`agreement_versions`, `approvals`, `approval_links`) stay, unread, for that
plugin to import from, until a later release drops them; events, notes and documents that pointed
at a version or a decision now point at its work. A piece of work is active until closed
(`work.state` is "active" or "closed", `active?`, `closed?`, `internal?`); nothing about it
waits on a client. `work.agreed_amount_cents`, `current_version`, `draft_version`,
`agreed_items` and the rest are gone, and approving creates no tasks. A `ScopeItem` is a section of
its work (`belongs_to :work`, `work.scope_items` in order; `description`,
`position`, `delivery_state` from its tasks); it has no price or estimate. `contact.can_approve?`
stays: who may say yes for their company, for a plugin to use. Times a client reads go inside
`client.in_time_zone { … }` (stable since 2.0).

A task can have several people on it (2.22, stable): `task.owner` stays the one who leads it, as
before, and `task.owners` (lead first), `task.other_owners` and `Task.assigned_to(user)` (tasks
someone leads or is on) read the rest. Setting `owner` replaces the lead and keeps the others.

## Events

| Call | Since | Status |
| --- | --- | --- |
| `ActiveSupport::Notifications.subscribe("event.runwell") { \|*, payload\| payload[:event] }` | 2.0 | Stable |

Every `Event` is published from a job after it's saved, never inside the request, so there is no
`Current.user`: read who did it from `event.actor_user` / `event.actor`, and where from
`event.source`. Its `subject` is the record and `kind` one of:

`client.created`, `client.status` (5.3: its status changed; payload `from` and `to`, recorded before
any `client.sunset` the change brings), `work.created`, `work.closed` (payload `outcome`: completed or
cancelled, since 2.17), `work.reopened` (2.17), `work.erased`, `task.converted` (2.17),
`client.prioritized` and `work.prioritized` (5.10: a client reordered their priorities in the
portal; the subject is the client, for their works, or the work, for its sections and tasks; payload
`kind` (work, scope_item or task), `id`, `name`, `rank` and `of`), `work.retyped` (5.9: its type changed, by a person or a merge; payload `from` and `to`, type keys;
its ref stays), `task.created`, `task.status`, `task.repeated` (5.9: a repeating task marked done made
the next one; payload `next_task_id`, `due_on`, `repeat`), `task.requested` (3.0: a client asked for it, from the portal or by
email, or someone logged it; the subject is the task), `note.added`, `note.deleted`, `document.added`,
`contact.previewed` (5.1.3: someone on staff viewed the portal as the contact, the subject), `contact.invited` (5.29: they were emailed an invitation to the portal) and `contact.signed_out` (5.29: staff signed them out of the portal everywhere; payload `sessions`), `contact.portal_scope` (5.31: what they see in the portal changed; payload `limited`, and `works`, their refs, when limited), `client.sunset` (5.2.2: the client was set dormant or former and its open work closed as
cancelled and open tasks marked done; payload `status`, `reason`, `works` (their refs) and `tasks` (how
many); each piece of work also records `work.closed` with that `reason`, and each task `task.status`
with a `reason` in its payload).

**Removed in 3.0:** `commitment.added`, `commitment.done`, `commitment.missed`,
`commitment.dropped`, `request.received` (now `task.requested`), `request.replied` (replies
to the acknowledgement are no longer taken in), `request.promoted`, `request.dismissed`, and
`agreement.sent`, `agreement.emailed`, `agreement.approved` and `agreement.changes_requested`
(the Agreements plugin records its own kinds on the work), and `question.answered` (the
`Question` model and its `answer_question` / `dismiss_question` tools are gone). Events recorded before keep their
kind, re-pointed at the tasks (or work, or client) they became.

New kinds may be added in any minor release; existing kinds keep their name and payload keys.

## Agents

| Call | Since | Status |
| --- | --- | --- |
| `agent_tool name, on:, title:, description:, params:, confirm:, next_tools:` in a controller | 2.0 | Stable |
| `confirm_when:` on `agent_tool`, a lambda of the call's arguments (string keys) for a tool that reaches the client only sometimes: it previews only when the lambda is true (`->(args) { Agent::Tool.truthy?(args.dig("task", "client_visible")) }`) | 5.16 | Stable |
| `agent_exempt action, reason:` | 2.0 | Stable |
| A param's spec as a lambda returning one (`label: -> { WorkType.active_keys }`), read each time the tools are listed, for choices the install sets | 5.9 | Stable |
| `Runwell::Plugins.agent_brief key, ->(task, base_url) { markdown or nil }` | 2.0 | Stable |
| `Runwell::Plugins.agent_workflow key, title, steps` | 2.1 | Stable |
| `Agent::Dispatch.run_as(user_or_contact, tool, arguments, name:)` | 2.18 | Experimental |
| `Agent::Catalogue.for(user)`, `.for_contact(contact)`, `.find(name)` and a tool's `name`, `title`, `description`, `read?`, `confirm`, `input_schema` | 2.18 | Experimental |

`Agent::Dispatch.run_as` runs one tool as a person or a client's contact, as their own agent would
over MCP: a token for that call alone (kept out of Connected apps), revoked after; `name:` is what
history says it came through ("Ted's agent via Runwell AI"). It's for an in-app assistant (the AI
plugin), which offers the catalogue's tools to a model.

A read needs a `.json.jbuilder` view starting each record with `json.merge! agent_ref(record)` and
a `summary`. A write needs nothing extra: its redirect and notice become the tool's answer. See
[agents.md](agents.md).

## In-app AI

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.ai_prompt key, label, types:` | 2.16 | Experimental |

The assistant itself is the AI plugin (2.18; before, the core). A one-click question in its Ask
panel, on the given record types (`Client`, `Work`, `Task`,
`ScopeItem`; `Request` until 3.0) or every page. The assistant answers through the agent tools, so a plugin's
declared tools are already within its reach while the plugin is on.

## Portal

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.portal_nav key, label, -> { path or nil }` | 2.0 | Stable |
| `portal_nav … replaces: :documents` | 5.13 | Stable |
| Controllers inheriting `Portal::BaseController` (`current_contact`, `client`) | 2.0 | Stable |

A portal page sees only the signed-in contact's client, and shows a client only what is marked
for them (`client_visible`).

Since 5.29: a client reads a task's status as `task.client_status` (`Task::CLIENT_STATUSES`:
received, planned, in_progress, on_hold, done; "in review" and "blocked" stay the team's), never
`task.status`; `Task.unread_discussion_ids(contact)` is the shared tasks holding a message that
contact hasn't read (`DiscussionRead`, moved on when they open the task); `contact.portal_emails?`
says whether they want mail about their work (check it before emailing a client's person anything
but a sign-in link); `Work#client_documents` no longer includes files on the client itself (those
are on the portal's Documents, `Client#client_documents`); and the portal's pages refresh live
(`turbo_stream_from client` in its layout), so a plugin's portal page whose records include
`LiveRefreshes` and name the client redraws by itself. The core's portal home is the client's work
and nothing else: a dashboard for the client is a plugin's, in the `:portal_dashboard` slot.

`replaces:` names one of the core's own portal pages the plugin's page stands in for (only
`:documents`, `Runwell::Plugins::REPLACEABLE_PORTAL_PAGES`). While the plugin is on, its link
takes that page's place in the portal nav (under the plugin's label) and the core's page redirects
people to it; agents' `portal_documents` tool still answers with the core's list. Switch the plugin
off and the core's page is back. A plugin that also runs on cores before 5.13 checks for the keyword
first (`Runwell::Plugins.method(:portal_nav).parameters`).

Since 5.30, in portal pages and slots: `portal_task_link_to(task) { … }` (a link opening a shared
task in the portal's side sheet), `portal_status_tag(task)`, `portal_due(task, prefix:)` (its date,
marked when late; `task.late?`), `portal_unread_mark(task)`, and the `documents/link` partial
(`document:`, `meta:`).

Since 5.31 a contact may be limited to some of their client's work (`contact.portal_limited?`,
set on their page). A portal page or tool reads what its contact sees, never the client's records
directly: `current_contact.portal_works`, `portal_tasks` (shared tasks, as a relation) and
`portal_documents`, and `contact.sees?(record)` for one record (a piece of work, a section, a
task, a document, a note). `Notice` already leaves out anyone who can't see what a notice is about;
a plugin emailing a client's people itself checks `sees?` too.

### Who hears about what

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.notices key, client: ->(kind:, client:, record:, usual:, everyone:) { … }, team: ->(…) { … }` | 5.30 | Stable |
| `Notice::CLIENT_KINDS`, `Notice::TEAM_KINDS` (kind => what it is, in words), `Notice.reachable_contacts(client)` | 5.30 | Stable |

Everything that passes between a client and the team goes through `Notice`, which asks plugins who
should hear. To a client's people, by email: `reply` (the team wrote on a task; `record` the note),
`taken_on` and `done` (something they asked for; the task), `document` (files shared; the latest
document). To the team, as notifications: `request` (a request from outside; the task) and `reply`
(a client wrote on a task; the note). Each lambda gets who would usually hear (`usual`) and
everyone who could (`everyone`: the client's people who can sign in to the portal and haven't
switched its mail off; the team's active people), and returns who does. The core keeps only those
in `everyone`, so a contact's own switch always wins. `client` is nil for a request emailed by
someone not on file. Either side may be left out; several plugins answer in turn, each given the
last one's answer as `usual`. `runwell-client-dashboard` is the reference.

## Public pages

| Call | Since | Status |
| --- | --- | --- |
| A controller inheriting `ApplicationController` with `allow_unauthenticated_access` and `layout "public"` | 2.0 (documented 3.0) | Stable |

A page someone opens from an emailed link without signing in (a client reading and signing
something): `allow_unauthenticated_access` skips sign-in and the authorization rules, and agent
tools ignore it. It finds its record by a signed or random token in the path, never an id, and
shows times inside `client.in_time_zone { … }` (an `around_action`). The portal's custom CSS rule
(Settings › Appearance) doesn't apply: the install's theme is on every page outside the portal.

## Email

| Call | Since | Status |
| --- | --- | --- |
| Mailers inheriting `ApplicationMailer` (the layout, the sender, the install's address in links) | 2.0 | Stable |
| `MailerHelper`: `mail_heading`, `mail_button`, `mail_quote`, `mail_small`, `content_for :preheader / :reason` | 2.10 | Stable |

## Record layouts

Template mode (5.1.3, Experimental) lets an install's owners arrange each kind of record's fields:
`RecordLayout.for(kind)` (`client`, `work`, `task`, `contact`, `user`) has `main`, `aside` and `hidden`, each a
list of field keys in order, and `required?(key)`. The core's keys are `RecordLayout::DEFAULTS`;
custom fields are `custom.<key>`. 5.9 added `cadence` (work) and `repeat` (task). A key is stable once released: a renamed key comes with a
migration of saved layouts. Layouts change only where fields show on the record's pages, never
what's stored or required. Plugins can't add fields to a layout yet; their panels stay in the
record's slots. Tools: `show_layout`, `arrange_layout`, `reset_layout` (owners), and
`settings.layout` is a security event (Settings > Audit log).

## Changes to this contract

**6.0** moved the core's UI from rune_ui to runeui (`docs/runeui-migration.md`): runeui's tokens
(shadcn's) on `:root`, its components everywhere in the core, and Settings › Appearance and custom
CSS acting on those tokens. Plugins keep working through the compatibility layer above, until 7.0:
rune_ui's helpers drawn by runeui, its classes, and its token names defined from runeui's (the
table above), with a plugin stylesheet's `var(--accent)` and `var(--ring)` read as the brand's
colour and the focus shadow. To move, a plugin draws with `ui :name` and `form.ui`, reads runeui's
tokens (`--primary` for the brand's colour, `--muted-foreground`, `--border`, `--ui-focus-ring`…),
and sets `requires: ">= 6.0.0"`. Gone in 6.0: Fizzy's palette (`--lch-*`) and `--text-scale`,
which no plugin read; and the compatibility classes listed above as gone. Dark mode is runeui's
`.dark` on `<html>`, set before the first paint; `html[data-theme="dark"]` still matches (runeui
sets it beside `.dark`, now also when dark comes from the system), but a new dark rule is
`.dark …`.

**5.1.1** folded a client's contacts into users: a contact is a `User` with the role `client`
(`User::Role::CLIENT`), and `Contact` is that slice of users (`class Contact < User`, a default
scope), so `Contact`, `contact_id`, `task.contact`, `client.contacts`, `current_contact` and the
`*_contact` tools read as before, and contacts show in Users beside the team. What changed:

| Before 5.1.1 | From 5.1.1 |
| --- | --- |
| a contact's id (the `contacts` table) | a new user id: `users.legacy_contact_id` holds the old one |
| `contact.role` (their job title) | `contact.title`; `role` is `"client"` |
| `contact.email`, `contact.archived_at` | still read and written (aliases of `email_address`, `deactivated_at`) |
| `PortalSession` | `Session` (`contact.portal_sessions`); a session, token or grant reads `user` for staff and `contact` for a client's person (`HeldByPerson`) |
| `User.people` | the team only: never a client's person; `User.clients`, `User.staff`, `user.client?` |

A plugin whose own tables keep a `contact_id` repoints it in a migration of its own:
`UPDATE agreements_approvals SET contact_id = (SELECT id FROM users WHERE legacy_contact_id = agreements_approvals.contact_id)`.
The core's `contacts` and `portal_sessions` tables are left, unread, for a later release to drop.

**5.0.3** renamed the core's two nouns everywhere, with no aliases: engagements are **Work** and
todos are **Tasks**. A plugin moving to 5.0.3 renames what it uses (and sets `requires: ">= 5.0.3"`):

| Before 5.0.3 | From 5.0.3 |
| --- | --- |
| `Engagement`, `engagements`, `engagement_id`, `/engagements/P-3` | `Work`, `works`, `work_id`, `/work/P-3` |
| `Todo`, `todos`, `todo_id`, `/work/42` | `Task`, `tasks`, `task_id`, `/tasks/42` |
| slots `:engagement_panel`, `:engagement_aside`, `:engagement_meta`, `:portal_engagement_panel` | `:work_panel`, `:work_aside`, `:work_meta`, `:portal_work_panel` |
| slots `:todo_panel`, `:todo_aside` | `:task_panel`, `:task_aside` |
| load hooks `:runwell_engagement`, `:runwell_todo` | `:runwell_work`, `:runwell_task` |
| events `engagement.*`, `todo.*` | `work.*`, `task.*` |
| tools `*_engagement`, `*_work` (todos), `list_work` | `*_work`, `*_task`, `list_tasks` |
| `term(:engagement)`, `term(:work)` | `term(:work)`, `term(:task)` |
| permissions `close_engagements`, `erase_engagements` | `close_works`, `erase_works` |

A plugin's own tables that point at core records by `engagement_id` or `todo_id`, or store a
polymorphic type of `"Engagement"` or `"Todo"`, need a migration of their own; the core's 5.0.3
migration renames only the core's tables, columns and stored types.

**5.0** ignores `enabled_by_default:` (every plugin starts off) and removed the core's home page, the briefing ("Needs You"), with its two extension points:
the `:home_top` slot and `Runwell::Plugins.briefing`. The app opens on Tasks. A plugin that showed
something on home gives it a page of its own with `Runwell::Plugins.nav` (a dashboard is a plugin's
to make). Until a plugin drops them, `briefing` is a no-op that logs a warning and a `:home_top`
registration is kept but rendered nowhere, so an older plugin still boots.

**4.0** moved the core's UI from nobuild_ui and Fizzy's stylesheets to rune_ui. Removed: every
`ui-*` class and nobuild_ui's helpers (`ui_button`, `ui_link_button`, `ui_button_classes`,
`ui_badge`, `ui_kbd`, `ui_avatar`, `ui_dropdown`, `ui_menu_*`); Fizzy's component classes (`btn--*`
other than rune's, `panel`, `popup` outside `popup_menu`, `input`, `status-tag`, `blank-slate`)
and utility classes (`flex`, `gap`, `txt-*`, `margin-*`, `pad-*`, `for-screen-reader`…); the
mask icons and their SVG files; shadcn's tokens (`--primary`, `--card`…). What replaces each is in
[upgrading-to-4.md](upgrading-to-4.md).

Each release's notes say what it added here. This page lists the version each call arrived in, so
a plugin can set `requires:` to the newest one it uses.
