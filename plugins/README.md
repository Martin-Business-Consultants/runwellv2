# Installed plugins

One directory per plugin, each a Rails engine gem with a gemspec at its root. The Gemfile
loads every `plugins/*/*.gemspec` it finds. Nothing here is tracked by git: this directory
belongs to the install, like its database.

```sh
bin/rails "plugins:install[https://github.com/org/runwell-thing]"   # clone, bundle, migrate
bin/rails "plugins:update[runwell-thing]"                          # pull the latest
bin/rails "plugins:remove[runwell-thing]"                          # delete the code; tables stay
bin/rails plugins:list
```

Then switch the plugin on in Settings > Plugins. A Docker install rebuilds its image after
installing (the Dockerfile copies this directory in).
