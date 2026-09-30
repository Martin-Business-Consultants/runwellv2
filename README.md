# Runwell v2

The core of agency project management. See `AGENTS.md` for the guide,
`docs/install.md` to run your own (Docker or not), `docs/plugins.md` to extend it,
and `docs/future_apps.md` for what was deliberately left out.

```sh
bin/setup      # gems, npm, database, seeds
bin/dev        # http://localhost:3000, sign in as ted@brem.io / password
bin/rails test
```

Releases and self-hosting: https://github.com/Martin-Business-Consultants/runwellv2/releases and
`docs/install.md`. Licensed under the Functional Source License (FSL-1.1-MIT, `LICENSE.md`):
use it, change it and run it for yourself or your clients, but not to offer a competing
product; each release becomes MIT two years after it's published.

Client portal: `/portal` (magic link by email; in development read it at
`/letter_opener`). Approval links: `/approve/<token>`.
