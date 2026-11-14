# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: runeui", "bin/rails runeui:lint"
  step "Style: Templates", "bundle exec herb lint app/views"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
  # The seeds' sample data would break the next test run's fixtures.
  step "Tests: Clean up", "bin/rails db:test:prepare"
end
