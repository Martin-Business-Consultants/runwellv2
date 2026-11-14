source "https://rubygems.org"

gem "bcrypt"
gem "bootsnap", require: false
gem "csv"
gem "geared_pagination"
# Herb 0.11.2 (and ReActionView 0.6.1, which needs it) serializes with Prism 2.1, and the bundle
# can't have prism 2 while rubocop-ast pins it to 1.x: every page with state failed to render
# ("Invalid serialization"). Lift both pins together once rubocop-ast allows prism 2.
gem "herb", "0.11.1"
gem "image_processing"
gem "importmap-rails"
gem "jbuilder"
gem "kamal", require: false
gem "lexxy"
gem "mcp"
gem "positioning"
gem "matrix" # prawn needs it and doesn't say so; not a default gem since Ruby 3.1
gem "prawn"
gem "propshaft"
# shadcn/ui in plain CSS, no build step: the ui- components (Runwell UI)
gem "runeui", github: "Martin-Business-Consultants/runeui", branch: "master" # the UI kit: components on UI SDK (docs/runeui-migration.md)
gem "puma"
gem "rails"
gem "rails-active_search"
gem "reactionview", "0.6.0" # pinned with herb, above
gem "rotp"
gem "web-push" # notifications pushed to a person's browser or installed app (PushSubscription); plugins may use it too
gem "rqrcode"
gem "ruby_llm"
gem "rubyzip", require: "zip"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "sqlite3"
gem "stimulus-rails"
gem "thruster", require: false
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development do
  gem "letter_opener_web"
  gem "web-console"
end

group :development, :test do
  # N+1 queries: logged in development, and a failure in tests (config/initializers/prosopite.rb).
  # pg_query lets Prosopite fingerprint queries on databases other than MySQL.
  gem "pg_query"
  gem "prosopite"
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end
