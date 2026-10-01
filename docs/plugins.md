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
each extension point, and `AGENTS.md` (Plugins) lists them all.

## Developing one

Clone it beside a Runwell checkout and link it in: `bin/rails "plugins:link[../runwell-hello]"`,
then `bin/rails db:migrate` and `bin/dev`. Tests don't load plugins: the core's suite covers the
core alone.

## Releasing one

Bump its `VERSION`, tag `vX.Y.Z` and publish a GitHub release (`gh release create vX.Y.Z
--generate-notes`). Installs see it with Check for updates in Settings > Plugins, or the next
night.

## Where plugins come from

`config/plugins.yml` lists the ones Runwell's authors publish, which Settings > Plugins offers
with an Install button: Account management, Cloudflare, Code, Factory, Google Ads, Outsend, QA,
QuickBooks, Reporting and Time tracking, each at
`github.com/Martin-Business-Consultants/runwell-<name>`. Any other repository installs the same
way, by `owner/name`.
