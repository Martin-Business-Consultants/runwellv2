source "https://rubygems.org"

gem "bcrypt"
gem "bootsnap", require: false

# Deploy with Kamal; Thruster fronts Puma in the image (gzip, asset caching, X-Sendfile).
gem "kamal", require: false
gem "thruster", require: false
# Account management: client leads, meeting agendas and recaps, the access register, weekly updates, scorecards.
gem "account_management", path: "engines/account_management"
gem "cloudflare", path: "engines/cloudflare"
gem "coding", path: "engines/coding"
# Factory: ready work handed to AI agents on runners (engines/factory, runner in runner/).
gem "factory", path: "engines/factory"
gem "google_ads", path: "engines/google_ads"
gem "herb"
gem "image_processing"
gem "importmap-rails"
gem "jbuilder"
gem "lexxy"
gem "mcp"
gem "outsend", path: "engines/outsend"
gem "positioning"
gem "propshaft"
gem "puma"
# QA: each client's source of truth and the proof it was tested (engines/qa).
gem "qa", path: "engines/qa"
gem "quickbooks", path: "engines/quickbooks"
gem "rails"
gem "rails-active_search"
gem "reactionview"
gem "reporting", path: "engines/reporting"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "sqlite3"
gem "stimulus-rails"
gem "time_tracking", path: "engines/time_tracking"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Bundled plugins ship with the core (engines/, above). Installed ones live in plugins/, one
# gem each, put there by bin/rails plugins:install; see plugins/README.md.
Dir.glob(File.expand_path("plugins/*/*.gemspec", __dir__)).each do |gemspec|
  gem File.basename(gemspec, ".gemspec"), path: File.dirname(gemspec)
end

group :development do
  gem "letter_opener_web"
  gem "web-console"
end

group :development, :test do
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "geared_pagination", "~> 1.2"
