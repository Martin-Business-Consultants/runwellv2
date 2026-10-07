# Plugins

A plugin is a Rails engine with a gemspec at its root: an `app/` for its models, controllers
and views, `db/migrate/` for its own tables, and a `lib/<name>/engine.rb` that registers what it
adds. The core never names a plugin and never lends it a table: everything a plugin keeps lives
in tables it owns, prefixed with its name, pointing at core records by id.

Plugins aren't part of the core's repository or its image. Each is a public GitHub repository
with releases, installed onto a server from **Settings > Plugins** (or
`bin/rails "plugins:install[owner/repo]"`). Runwell downloads the latest release into
`RUNWELL_DATA_DIR/plugins/<name>` (beside the databases, so it outlasts deploys and core
updates), restarts, and loads it at boot (`config/installed_plugins.rb`). Its migrations run
after the core's, and its stylesheets compile as it boots. A plugin updates only when someone
presses its Update button, which appears when its repository has a newer release; Remove
deletes its code and keeps its tables.

Plugins aren't bundled (Bundler freezes the Gemfile in production), so a plugin can use only
the gems the core bundles.

## The smallest plugin

```
runwell-hello/
  hello.gemspec
  lib/hello.rb              # require "hello/version"; require "hello/engine"
  lib/hello/version.rb      # Hello::VERSION = "0.1.0"
  lib/hello/engine.rb
```

```ruby
module Hello
  class Engine < ::Rails::Engine
    config.to_prepare do
      Runwell::Plugins.register :hello, name: "Hello", version: Hello::VERSION, author: "You",
        requires: ">= 2.1.0", homepage: "https://github.com/you/runwell-hello",
        description: "A note on every client's page."
      Runwell::Plugins.slot :client_panel, :hello, "hello/slots/client_panel"
    end
  end
end
```

The gemspec's name is the plugin's key and its table prefix. `requires:` is a gem requirement on
the core's version (the `VERSION` file); Settings > Plugins says when a plugin needs a newer
core. Routes are appended to the app's from an initializer; migrations need nothing, since the
core runs every installed plugin's `db/migrate`. `runwell-time-tracking` is the reference for
each extension point, and [the plugin contract](plugin-contract.md) lists them all, with the
core version each arrived in.

## Developing one

Clone it beside a Runwell checkout and link it in: `bin/rails "plugins:link[../runwell-hello]"`,
then `bin/rails db:migrate` and `bin/dev`. Tests don't load plugins: the core's suite covers the
core alone.

## Releasing one

Bump its `VERSION`, tag `vX.Y.Z` and publish a GitHub release (`gh release create vX.Y.Z
--generate-notes`). Installs see it with Check for updates in Settings > Plugins, or the next
night.

## Start one

Use [runwell-plugin-template](https://github.com/Martin-Business-Consultants/runwell-plugin-template)
(GitHub's "Use this template"), then `bin/rename "Your plugin"`. It is a small working plugin that
uses every common part of [the contract](plugin-contract.md), with an AGENTS.md for AI agents
working on it.

## Where plugins come from

`config/plugins.yml` lists the ones Runwell's authors publish, which Settings > Plugins offers
with an Install button: Account management, Cloudflare, Code, Factory, Google Ads, Meetings,
Outsend, QA, QuickBooks, Reporting and Time tracking, each at
`github.com/Martin-Business-Consultants/runwell-<name>`. Any other repository installs the same
way, by `owner/name`.

## The plugins Runwell publishes

Each is the reference for a kind of plugin. Read the one closest to yours.

`runwell-time-tracking` is the reference for the extension points: minutes logged on clients,
engagements and todos (a polymorphic `trackable`, like notes and documents, with the engagement and
client kept alongside so totals roll up), totals on engagements, a weekly timesheet, and "Log time"
in the quick action tray. No live timers.

`runwell-ai` (AI) is the reference for a plugin that runs agent tools for a person and fills the
row and sidebar slots: an assistant inside the app (Ask, `i`) and one-click suggestions on records,
through RubyLLM and the install's own provider key, with a monthly budget. It offers the catalogue's
tools to a model and runs each as the person with `Agent::Dispatch.run_as`, so writes wait for their
approval and history reads "Ted's agent via Runwell AI". It owns RubyLLM's tables too
(`tables: [ ruby_llm_ ]` in `config/plugins.yml`). It was in the core until 2.18; an install that had
it on gets the plugin on updating, its first migrations taking over the tables and copying the
settings.

`runwell-google-ads` is the reference for a plugin that reaches the portal: read-only Google
Ads reporting. The owner connects their own Google API app in Settings > Google Ads (OAuth,
credentials encrypted with Active Record encryption); an engagement links to an ad account
(`GoogleAds::Link`, permission `link_ad_accounts`); a nightly sync copies monthly and daily
figures; staff and the client see the same report (server-drawn SVG charts,
`GoogleAds::ReportsHelper`), and an account that stops serving shows on home and emails the
listed addresses. No management fee: the core has no money.

`runwell-outsend` is the reference for a plugin that changes how the core does something
without a hook: a Mail interceptor routes each message through Outsend while the plugin is on
and has a key (Settings > Outsend, encrypted), so the core needs no mail extension point.
`runwell-cloudflare` is the reference for a plugin with middleware and no tables: inserted
before `ActionDispatch::SSL`, it trusts `CF-Connecting-IP` only when the connection came from
a Cloudflare range (bundled list, refreshed nightly) and marks the request https.

`runwell-coding` (Code) is the reference for a plugin that takes webhooks: git repositories
linked to clients, engagements and todos (`Coding::Repository`, a polymorphic `linkable`; a
todo inherits its engagement's repos and an engagement its client's). `checkout_work` hands an
agent the clone commands, branch (`p-4/58-slug`) and agreed scope; `log_progress`,
`finish_work` and `flag_out_of_scope` (a request to triage) report back. Connected to GitHub in
Settings > Code (OAuth), a signed public endpoint (`/code/github/webhooks`) brings in pull
requests and checks on work (a merge can mark the todo done), deploys (production ones on the
engagement timeline, and in the portal when shared), labelled issues as requests, and commits,
from which time is suggested when Time tracking is on. A deactivated person who can still reach
a linked repo shows on home. It never pushes code or stores secrets.

`runwell-factory` (Factory) is the reference for a plugin that hands work to agents running
unattended. A person queues a todo (`Factory::Item`, with optional instructions) once it is ready
(`Factory::Readiness`: approved scope, a description or scope item, a linked repository from the
Code plugin, a client that allows it), or an approval queues its engagement's ready work
(`queue_on_approval`). A runner claims the next item with a lease (`claim_work`, earliest due first,
no priorities), renews it (`heartbeat_run`) and ends it (`finish_run`); a `Factory::Run` records the
runner, branch, pull request, summary and cost. Success puts the todo in review; failure frees it
for another attempt or blocks it once `max_attempts` are used; a lapsed lease abandons the run.
Limits live in `Factory::Policy` (runs at once, time, attempts, monthly budget, blocked clients).
What the agent is told is `Factory::Task`, served with each run. The runner is a separate Rust
binary in the plugin's `runner/` that talks only to `/mcp`; it never merges.

`runwell-quickbooks` is where money lives, since the core holds none. A client links to a
QuickBooks customer by id (`Quickbooks::Customer`). A service links to a recurring invoice
template (`Quickbooks::RecurringLink`) that Runwell keeps in step: an approved revision
changes it and closing the service stops it (both from `"event.runwell"`, run in jobs), and
the nightly sync flags a template edited in QuickBooks so it no longer matches (`drift`).
Fixed-price work is invoiced from its panel (`Quickbooks::WorkOrderBilling`), in full or as a
deposit whose balance can be armed to send when the engagement is closed; QuickBooks emails
each with its pay link, and the portal lists open invoices with a Pay button. Every write to
the books is a named method on `Quickbooks::Api`. `runwell-reporting` has no tables: it reads
the QuickBooks mirror (billed, collected, aging, by client, recurring coverage, approved but
not invoiced) and QuickBooks' profit and loss, for `view_financials`. A nav path lambda may
return nil to hide its link.

`runwell-qa` (QA) is the reference for a plugin that adds a rule to a core model. A client's
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
`bin/rails "qa:import[path/to/file.yml]"` loads a client's checks from a file (the plugin's `examples/acme_storage.yml`).

`runwell-account-management` (Account management) is the working system of whoever runs client
relationships, switched on per person (`AccountManagement::Member`, Settings > Account management);
each chooses every client or a group (My clients), and the clients they lead or back up are always
theirs. It does five things, each a page in its section sidebar (`section_nav`, the reference for
it): Today (`Cockpit`) lists what needs someone across their clients, overdue first, with snoozes.
Clients shows each one's lead (`Lead`, with a backup who covers while the lead is away and a contact
cadence), its weekly health (`HealthCheck`) and when it last heard from us (`Pulse`: logged contacts,
meetings, non-internal notes, requests and agreements). Contacts are logged (`Touch`, the Contact
quick action), and requests are answered within a business day (`Replies`). Meetings hold the
agenda, due `AGENDA_AHEAD` before, and the recap, due `RECAP_WITHIN` after, both draftable from the
records (`Meeting::AgendaDraft`), on rhythms (`MeetingSeries`, planned nightly). Calls: an AI
harness debriefs a call (the plugin's agent workflow): `debrief_call` gives the client's open
engagements and agreed scope, its people, and the team with each person's expertise tags
(`Expertise`, set in its settings) and open work; `record_call` (preview first) makes the call note,
the contact, todos on the right engagements with owners, commitments, requests and health at once
(`Call::Plan`). Home (`Attention`) warns before a standard is missed. Its guide is `docs/guide.md`
in its repository, and Accounts > Guide.

`runwell-stripe-billing` (Stripe) takes payment for what was approved. On `agreement.approved` it
makes a `StripeBilling::Charge` per version, in the request, so the approval page
(`:approval_page`) offers the link straight away and the client is emailed it: a service's first
approval starts a subscription on the cadence, a later revision or add-on moves that subscription
to the new amount, fixed work is a one-time link for the initial price and then each change
order's difference. Each charge has a `paid` flag, set by Stripe's signed webhook or recorded with
a note by someone with `manage_billing` (which switches the link off). A service is billed once
(`StripeBilling::Subscription` is unique per engagement, one open subscription link, a second
subscription cancelled at once), and Stripe and QuickBooks each refuse a service the other bills.
Stripe connects with OAuth (Stripe Connect) through a broker on the install holding the platform's
keys (`STRIPE_CONNECT_CLIENT_ID`, `STRIPE_CONNECT_SECRET_KEY`), which hands each install its token
server to server against a PKCE-style verifier.

`runwell-meetings` (Meetings) is a team's daily rhythm. Each person picks the day's priorities
(`Meetings::Priority`: a todo, done when the todo is, or a line of their own, ticked off by hand)
and carries over the previous weekday's unfinished ones. A meeting (`Meetings::Meeting`, with its
people, agenda and notes) shows each person beside their priorities for its day, next to open work
to pick from. A meeting repeats through a `Meetings::Series` (every weekday, chosen weekdays every
week or two, or monthly on the same weekday), planned a week ahead and nightly; changing the series
changes the meetings still to come. At the end of the day each
person writes a `Meetings::Report` (what went well, what didn't, why, what's next), read a day at a
time across the team. Home (`:home_top`) shows your priorities and next meeting, and asks for the
report from the afternoon on.
