# Future apps

Runwell v2 is the core: who we work for, what we run for them, what is happening
on it, what came in, and what needs a person now. Everything below was in
the first Runwell and was left out on purpose. Each is a candidate for a separate
app or a plugin that talks to the core through its API, events and
identifiers, never through the core's tables.

## Money (QuickBooks)

Runwell never holds money and has no notion of "billable": everything is a
project, work order or service. Agreements, with any price in their text, are the Agreements
plugin's (3.0); a QuickBooks or Stripe plugin keeps its own amounts per engagement and its own
record of what it has invoiced or charged.

Left out with it: invoices, invoice items, payments, recurring invoices,
expenses, financials (daily brief, losses, revenue), customer billing and costs,
Stripe billing for the install's own subscription.

Recurring engagements: the core stores the agreed cadence and amount per period.
Period confirmation (with inputs such as ad spend for percent-of-spend pricing)
belongs to the money tool or a small periods plugin, which keeps its own
records.

## Time tracking

Not in the core, but available as the first plugin (`Martin-Business-Consultants/runwell-time-tracking`): timers and
logged time on todos, totals per engagement and a weekly timesheet, in its own table and
reading engagements and todos by id. Estimates stay internal inputs to pricing.

## Dashboards, daily reports, weekly work

Dropped. The briefing ("Needs you") is the one home page. Boards over the core
queries (overdue work, awaiting client, blocked work) can be generated as
read-only views later; they must not carry state of their own.

## Recipes

Reusable todo bundles applied to a project. If wanted again: a plugin that
creates todos through the API from a stored template.

## Specs

Spec documents with sources, revisions, reviews and questions. A separate app
that links to an engagement by ref and may add sections (scope items) to it.

## Questionnaires

Client intake forms with templates and public links. A separate app whose
answers arrive in the core as a request (work nobody has taken on) with source "questionnaire: <name>".

## Prospecting

Prospect lists, DataForSEO and Nominatim enrichment, email finding. Not project
management. A separate app that creates a Client in the core when a prospect
converts.

## Generic documents

Rich documents with blocks, tags, public links and signing. Removed from the core. Agreements
the client signs are the Agreements plugin's (3.0).

## Agents and GitHub

The first Runwell had AI tasks, workers, PR review, GitHub App installs and
infrastructure records on partners, projects and services. In v2 an agent is an
actor: it writes events, notes, requests and questions with a source, with its person's
permissions. Code
hosting integrations (repos, PRs, deploy previews) are a peer tool that logs
events against an engagement or todo by id.

## Google Ads and other identifiers

Ad platform sync and percent-of-spend fees. A peer tool that supplies period
inputs. The core should gain a small `identifiers` registry (kind, value) on
clients so a tool can find its own records without the core knowing what a
Google Ads customer id means.

## Multi-tenancy, signup, Stripe trial

v2 is single-tenant. Hosting many businesses (subdomain tenancy, signup,
provisioning, subscription billing) is a hosting layer added later and must not
change the domain model.

## Also dropped

Notifications inbox and thread digests (email is sent for
portal sign-in only), impersonation, device authorizations, API tokens, MCP and
CLI front doors (to be re-added over the same controllers), Rails Pulse, search
across records, record panels, tags and categories, builder and
catalogue scaffolding.
