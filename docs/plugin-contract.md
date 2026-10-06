# The plugin contract

Everything a plugin may rely on from the core, with the core version it arrived in. A plugin's
manifest says which cores it works with (`requires: ">= 2.12"`), and Settings › Plugins flags one
that needs a newer core. How to build, develop and release a plugin is in
[plugins.md](plugins.md); the
[plugin template](https://github.com/Martin-Business-Consultants/runwell-plugin-template) is a
working starting point.

**Stable** means it keeps its name, arguments and meaning within the major version (2.x): a change
that would break a plugin waits for 3.0, and anything going away is marked deprecated first, for at
least one minor release. **Experimental** may change in a minor release, said in its release
notes.

What is *not* in the contract: core class names other than those below, core tables and columns
(read them through the models; never write to them directly), view markup and CSS classes, private
methods, and anything under `Agent::`, `Upgrade`, `PluginChange` or `Setting`'s internals.

## Rules a plugin keeps

- It owns its tables, prefixed with its key (`time_tracking_entries`), pointing at core records by
  id. It never adds columns to, or writes rows in, core tables except through the core's own model
  verbs (`todo.update(status: …)`, `client.record_event!(…)`).
- It registers everything in its engine's `config.to_prepare`, keyed by its key, and its
  controllers and subscribers check `Runwell::Plugins.enabled?(key)`. The core renders a plugin's
  registrations only while it's on.
- Its controllers declare an authorization rule and an agent tool (or `agent_exempt`) per action,
  as the core's do. Its migrations are safe on a live install.
- Removing it leaves the core working: nothing in the core names a plugin.
- It uses only the gems the core bundles (it is loaded outside Bundler).

## Manifest

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.register key, name:, version:, description:, author:, enabled_by_default:, requires:, homepage:` | 2.0 | Stable |

`requires:` is a gem requirement on the core's `VERSION`. `enabled_by_default:` should be false for
anything published: an owner switches a plugin on.

## Views

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.slot name, key, partial` | 2.0 | Stable |
| `Runwell::Plugins.nav key, label, -> { path or nil }` | 2.0 | Stable |
| `Runwell::Plugins.stylesheet key, "name"` | 2.0 | Stable |
| `Runwell::Plugins.quick_action key, label:, icon:, partial:, types:, title:, context:` | 2.0 | Stable |
| `Runwell::Plugins.settings key, label, -> { path }` | 2.0 | Stable |
| `Runwell::Plugins.shortcut key, "i", "What it does"` | 2.18 | Stable |

Slots, and the locals each partial gets:

| Slot | Where | Locals | Since |
| --- | --- | --- | --- |
| `:client_panel` | A tab on each client | `client:` | 2.0 |
| `:engagement_panel` | A tab on each engagement | `engagement:` | 2.0 |
| `:todo_panel` | A tab on each piece of work | `todo:` | 2.0 |
| `:nav_actions` | A button in the nav's foot | none | 2.0 |
| `:portal_home` | The client portal's home | `client:` | 2.0 |
| `:portal_engagement_panel` | An engagement in the portal | `engagement:` | 2.0 |
| `:approval_page` | The client's approval page | `version:`, `link:` | 2.1 |
| `:email_inbound` | Settings › Email, how requests' mail comes in | none | 2.5 |
| `:home_top` | Home, above the briefing | none | 2.18 |
| `:client_aside` | A client's sidebar, above Details | `client:` | 2.18 |
| `:request_aside` | An open request's sidebar, above triage | `request_record:` | 2.18 |
| `:scope_item_aside` | A scope item's sidebar, above Details | `scope_item:` | 2.18 |
| `:draft_version` | Under a draft agreement version | `version:` | 2.18 |
| `:note_row` | Inside each note in a Notes section | `note:` | 2.18 |
| `:commitment_row` | Inside each commitment row | `commitment:` | 2.18 |
| `:portal_actions` | The portal header's buttons | `contact:` | 2.18 |

A slot partial declares strict locals on its first line, like every core partial. The row slots
(`:note_row`, `:commitment_row`) render once per row: work out anything shared once a request (a
`CurrentAttributes` of the plugin's own), never a query per row. A shortcut only lists a key on the
`?` sheet; the plugin's control declares it with `data-keys`, which is what makes it work. A nav or
settings path lambda runs in the view and may return nil to hide the link. A settings page's
controller says `require_permission :manage_settings` and starts its view with
`render "settings/header", current: key`.

Helpers a plugin's views may use: `term`, `label_term`, `person_tag`, `status_tag`, `rich_text`,
`rich_text_field`, `date_input`, `money`, `money_field`, `secret_field`, `code_block`, `icon_tag`,
`can?`, `current_record` (the record on screen, or nil; 2.18), `section_nav`, `section_nav_heading`
and `section_nav_link` (2.21), and the shared partials `layouts/shared/card`, `delete_dialog`, `confirm`, `row_actions`,
`quick_filter` and `index_toolbar` (2.0, stable). Design tokens for its CSS are in
[theming.md](theming.md) (2.12, stable).

A plugin with several pages of its own lists them in a sidebar beside the page, as Settings does:
each page calls `section_nav "Its name" do … end` once (a partial of the plugin's, given the
current page), with `section_nav_heading` over each group and
`section_nav_link label, path, icon:, current:` for each page. Below 960px it runs across the top.
The page itself then needs no links to its siblings. Since 2.21, stable.

## Home, permissions and the nightly run

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.briefing key, title, partial:, items: ->(user) { … }` | 2.0 | Stable |
| `Runwell::Plugins.permission key, :name, name:, roles:` | 2.0 | Stable |
| `Runwell::Plugins.nightly key, -> { … }` | 2.0 | Stable |

`roles:` is any of `owner`, `manager`, `member`. Check a permission with `user.can?(:name)` or `can?`
in views. A nightly task should enqueue a job rather than do slow work itself; one plugin failing
doesn't stop the others.

## Models

| Hook | Since | Status |
| --- | --- | --- |
| `ActiveSupport.on_load(:runwell_client) { has_many … }` | 2.0 | Stable |
| `ActiveSupport.on_load(:runwell_engagement) { … }` | 2.0 | Stable |
| `ActiveSupport.on_load(:runwell_todo) { … }` | 2.0 | Stable |
| `ActiveSupport.on_load(:runwell_user) { … }` | 2.0 | Stable |

Add associations, scopes and validations there; never columns. Core models a plugin may read and
call verbs on: `Client`, `Contact`, `Engagement`, `AgreementVersion`, `ScopeItem`, `Approval`,
`Todo`, `Commitment`, `Request`, `Note`, `Document`, `Event`, `User` (2.0, stable), and
`Setting.current.record_event!` for a settings change worth the audit log (2.18, stable).

## Events

| Call | Since | Status |
| --- | --- | --- |
| `ActiveSupport::Notifications.subscribe("event.runwell") { \|*, payload\| payload[:event] }` | 2.0 | Stable |

Every `Event` is published from a job after it's saved, never inside the request, so there is no
`Current.user`: read who did it from `event.actor_user` / `event.actor`, and where from
`event.source`. Its `subject` is the record and `kind` one of:

`client.created`, `engagement.created`, `engagement.closed` (payload `outcome`: completed or
cancelled, since 2.17), `engagement.reopened` (2.17), `engagement.erased`, `todo.converted` (2.17),
`agreement.sent`, `agreement.emailed`, `agreement.approved`, `agreement.changes_requested`,
`todo.created`, `todo.status`, `commitment.added`, `commitment.done`, `commitment.missed`,
`commitment.dropped`, `request.received`, `request.replied`, `request.promoted`,
`request.dismissed`, `question.answered`, `note.added`, `note.deleted`, `document.added`.

New kinds may be added in any minor release; existing kinds keep their name and payload keys.

## Agents

| Call | Since | Status |
| --- | --- | --- |
| `agent_tool name, on:, title:, description:, params:, confirm:, next_tools:` in a controller | 2.0 | Stable |
| `agent_exempt action, reason:` | 2.0 | Stable |
| `Runwell::Plugins.agent_brief key, ->(todo, base_url) { markdown or nil }` | 2.0 | Stable |
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
panel, on the given record types (`Client`, `Engagement`, `Todo`,
`Request`, `ScopeItem`) or every page. The assistant answers through the agent tools, so a plugin's
declared tools are already within its reach while the plugin is on.

## Portal

| Call | Since | Status |
| --- | --- | --- |
| `Runwell::Plugins.portal_nav key, label, -> { path or nil }` | 2.0 | Stable |
| Controllers inheriting `Portal::BaseController` (`current_contact`, `client`) | 2.0 | Stable |

A portal page sees only the signed-in contact's client, and shows a client only what is marked
for them (`client_visible`).

## Email

| Call | Since | Status |
| --- | --- | --- |
| Mailers inheriting `ApplicationMailer` (the layout, the sender, the install's address in links) | 2.0 | Stable |
| `MailerHelper`: `mail_heading`, `mail_button`, `mail_quote`, `mail_small`, `content_for :preheader / :reason` | 2.10 | Stable |

## Changes to this contract

Each release's notes say what it added here. This page lists the version each call arrived in, so
a plugin can set `requires:` to the newest one it uses.
