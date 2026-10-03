source "https://rubygems.org"

gem "bcrypt"
gem "bootsnap", require: false

# Deploy with Kamal; Thruster fronts Puma in the image (gzip, asset caching, X-Sendfile).
gem "kamal", require: false
gem "thruster", require: false
gem "herb"
gem "image_processing"
gem "importmap-rails"
gem "jbuilder"
gem "lexxy"
gem "mcp"
gem "positioning"
gem "propshaft"
gem "puma"
gem "rails"
gem "rails-active_search"
gem "reactionview"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "sqlite3"
gem "stimulus-rails"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Plugins aren't gems here: they're installed on the server (RUNWELL_DATA_DIR/plugins) and
# loaded at boot by config/installed_plugins.rb, so they may use only what's bundled above.

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

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "geared_pagination", "~> 1.2"

# Two-factor sign-in: authenticator codes (TOTP) and the QR code that sets them up
gem "rotp"
gem "rqrcode"

# Signing in with Google, Microsoft or GitHub (Settings > Sign-in)
gem "omniauth"
gem "omniauth-rails_csrf_protection"
gem "omniauth-google-oauth2"
gem "omniauth-github"
gem "omniauth-entra-id"
