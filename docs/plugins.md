# Plugins

A plugin is a Rails engine packaged as a gem: a directory with a gemspec at its root, an
`app/` for its models, controllers and views, `db/migrate/` for its own tables, and a
`lib/<name>/engine.rb` that registers what it adds. The core never names a plugin and never
lends it a table: everything a plugin keeps lives in tables it owns, prefixed with its name,
pointing at core records by id.

Bundled plugins live in `engines/` in the core's repository and ship with every release. Any
other plugin is its own git repository, installed into an install's `plugins/` directory with
`bin/rails "plugins:install[url]"`. Both are loaded the same way.

## The smallest plugin

```
runwell-hello/
  hello.gemspec
  lib/hello.rb              # require "hello/engine"
  lib/hello/engine.rb
```

```ruby
module Hello
  class Engine < ::Rails::Engine
    config.to_prepare do
      Runwell::Plugins.register :hello, name: "Hello", version: "0.1.0", author: "You",
        requires: ">= 2.0", homepage: "https://github.com/you/runwell-hello",
        description: "A note on every client's page."
      Runwell::Plugins.slot :client_panel, :hello, "hello/slots/client_panel"
    end
  end
end
```

`requires:` is a gem requirement on the core's version (the `VERSION` file). Settings > Plugins
says when a plugin needs a newer core. Routes are appended to the app's, migrations added to
its paths, from initializers; `engines/time_tracking` is the reference for each extension
point, and `AGENTS.md` (Plugins) lists them all.

## Where plugins come from

Any git host. There is no marketplace to publish to: a plugin is a repository, and its README
says what it does. The core's own bundled plugins double as the examples. A curated list of
known plugins will live here as they appear.
