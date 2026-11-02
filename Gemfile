source "https://rubygems.org"

gem "bcrypt"
gem "bootsnap", require: false
gem "csv"
gem "geared_pagination"
gem "herb"
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
gem "puma"
gem "rails"
gem "rails-active_search"
gem "reactionview"
gem "rotp"
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

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
