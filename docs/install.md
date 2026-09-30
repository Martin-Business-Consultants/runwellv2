# Installing Runwell

Runwell is one Rails app with SQLite, run as one process (Puma behind Thruster, with the job
runner inside). Every install is its own copy with its own data directory: there is no shared
server, no tenant switch. Two ways to run it, the same code either way.

## What it needs

- Ruby, the version in `.ruby-version`, with a compiler for the SQLite gem (`build-essential`
  on Debian and Ubuntu, `libyaml-dev`, `libsqlite3-dev`, `git`)
- `libvips` for image previews
- A hostname people will use. Mail links point at it

## With Docker and Kamal (the default)

A Kamal deploy is one server, one image, one volume for the data. Copy
`config/deploy.example.yml` to `config/deploy.yml` and `.kamal/secrets.example` to
`.kamal/secrets` (both untracked, since they name your server), set the host, server address
and registry, then `kamal setup` the first time and `kamal deploy` after. The image runs `db:prepare` on boot,
so a new release migrates itself. One install per Kamal destination:
`config/deploy.acme.yml` and `kamal deploy -d acme`.

## Without Docker

From a checkout of a release tag:

```sh
git clone https://github.com/Martin-Business-Consultants/runwellv2.git runwell && cd runwell
git checkout v2.0.1
bin/install --host runwell.example --data-dir /var/lib/runwell
```

`bin/install` bundles the production gems, writes `.env` with fresh secrets, prepares the
database and compiles assets. Start it with `bin/thrust bin/rails server` (after loading
`.env`: `set -a; . ./.env; set +a`), or install `config/runwell.service` as a systemd unit.
Then open `/signup` to make the first owner; everyone else joins by invitation.

Thruster serves https itself when it can reach ports 80 and 443: set `TLS_DOMAIN` in `.env`.
Behind your own proxy, set `HTTP_PORT=8080` and `ASSUME_SSL=true`.

## Updating

A release is a `vX.Y.Z` tag on https://github.com/Martin-Business-Consultants/runwellv2. `bin/release 2.1.0` writes `VERSION`,
tags and pushes, and GitHub publishes the release (`.github/workflows/release.yml`). Every install checks for a newer one
each night, and an owner sees it on home and in **Settings > Updates**, with its notes and an
**Update** button. The button works one of two ways, depending on how the install runs
(`RUNWELL_UPDATES` forces one):

- **A plain install** (a checkout with a `.env`) runs `bin/update <tag>` in the background: fetch
  and check out the release, bundle, back up and migrate, compile assets, restart Puma. The
  checkout must belong to the user Runwell runs as. The repository is public, so fetching and
  the release check need no credentials. Output goes to `RUNWELL_DATA_DIR/updates/<n>/update.log`
- **A Docker install** starts the repository's **Deploy** workflow (`.github/workflows/deploy.yml`),
  which runs `kamal deploy` for the install's destination. Set `RUNWELL_GITHUB_TOKEN` (a
  fine-grained token on the repository: Contents read, Actions read and write) and, for anything
  but `config/deploy.yml`, `RUNWELL_DEPLOY_DESTINATION`. On GitHub, in the releases repository,
  make an environment named
  for the destination (`production` for the default) holding `DEPLOY_YML` (its
  `config/deploy.yml`), `DEPLOY_DESTINATION_YML` (its `config/deploy.<name>.yml`, for a
  destination), `SSH_PRIVATE_KEY`, `RAILS_MASTER_KEY` and the rest of its `.kamal/secrets`.
  The token is only for starting that workflow: checking for releases needs none

The page follows the update and says when the install is running the new version, or why it
failed. Until then the old version keeps running. By hand it's the same as before:

```sh
bin/update v2.1.0      # a plain install: fetch and check out the release, bundle, migrate, assets, restart
bin/update             # the same for whatever is checked out
kamal deploy           # a Docker install, from a checkout of the release
```

### Backups before migrating

In production, `db:migrate` and `db:prepare` (which `bin/update` and the Docker image's boot
run) first copy every database that has migrations to run into
`RUNWELL_DATA_DIR/backups/<time>-v<old version>/`, keeping the last five
(`RUNWELL_BACKUPS_KEEP`). A failed copy stops the migration. `bin/rails runwell:backup` takes one
at any time. To roll back: stop Runwell, copy the files over those in `RUNWELL_DATA_DIR`, and
run the version the folder names. Uploaded files aren't copied, since Active Storage never
changes a stored file.

Migrations have to be safe on a live install and on an older version still running beside a
newer database: add columns and tables in one release, and remove or rename them only in a later
one, once nothing reads them.

## Settings

All in `.env` (or the deploy's `env:`). Only `APP_HOST` and the secrets are required.

| Variable | What it is | Default |
| --- | --- | --- |
| `APP_HOST`, `APP_PROTOCOL` | The address in links, and its scheme | `localhost`, `https` |
| `PORT` | Puma's port (Thruster fronts it on `HTTP_PORT`) | 3000 |
| `RUNWELL_DATA_DIR` | Databases and uploaded files, together | `storage/` |
| `SECRET_KEY_BASE` | Signs sessions and links | from `config/credentials.yml.enc` |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `…_DETERMINISTIC_KEY`, `…_KEY_DERIVATION_SALT` | Encrypt stored API keys and tokens | from credentials |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, `SMTP_DOMAIN`, `SMTP_STARTTLS`, `SMTP_TLS` | Outbound mail. Without `SMTP_ADDRESS` nothing is sent | none |
| `TIME_ZONE` | The agency's time zone, a Rails name or IANA id. Times are stored in UTC; a client with its own zone sees its portal, approvals and emails in it | `Eastern Time (US & Canada)` |
| `MAIL_FROM` | The sender when Settings > Email leaves it blank | `Runwell <no-reply@APP_HOST>` |
| `ASSUME_SSL` | Trust that a proxy terminated TLS | `false` |
| `FORCE_SSL` | Redirect http to https and use secure cookies | `true` |
| `SOLID_QUEUE_IN_PUMA` | Run jobs inside the web process | set by the installer |
| `RAILS_MAX_THREADS`, `RAILS_LOG_LEVEL` | Puma threads, log level | 3, `info` |
| `RUNWELL_UPDATES` | How Settings > Updates updates: `local` (bin/update), `github` (the Deploy workflow) or `manual` (shows the command) | worked out from the install |
| `RUNWELL_RELEASES_REPO` | Where releases are published | `Martin-Business-Consultants/runwellv2` |
| `RUNWELL_GITHUB_TOKEN` | Starts the Deploy workflow (a Docker install updating itself). Not needed to check for releases | none |
| `RUNWELL_DEPLOY_DESTINATION`, `RUNWELL_DEPLOY_WORKFLOW` | The Kamal destination and workflow file a Docker install deploys itself with | blank (config/deploy.yml), `deploy.yml` |
| `RUNWELL_UPDATE_CHECK` | `false` stops the nightly check for a newer release | on |
| `RUNWELL_BACKUP_BEFORE_MIGRATE`, `RUNWELL_BACKUPS_KEEP` | Back up databases before migrating; how many backups to keep | on, 5 |

Who mail comes from is set in Settings > Email, which also sends a test message. Mail can instead
go through the Outsend plugin (Settings > Plugins, then Settings > Outsend for the key), which
needs no SMTP settings. Behind Cloudflare, switch on the Cloudflare plugin:
visitors' real addresses are recorded and `ASSUME_SSL` isn't needed.

## Plugins

Bundled plugins come with the release and are switched on in Settings > Plugins. Others are git
repositories, installed on the server:

```sh
bin/rails "plugins:install[https://github.com/org/runwell-thing]"
bin/rails "plugins:update[runwell-thing]"
bin/rails "plugins:remove[runwell-thing]"
```

They live in `plugins/`, which belongs to the install like its data. A Docker install
rebuilds its image after installing one. See `docs/plugins.md` for writing one.
