json.summary "#{@stats.failing} failing, #{@stats.due} due for a test, #{@stats.passing} passing; #{@stats.open_now} open issues, #{@stats.escapes} escapes in #{@stats.days} days"
json.stats do
  json.days @stats.days
  json.extract! @stats, :failing, :due, :passing, :tests, :pass_rate, :opened, :caught, :escapes, :escape_rate, :median_hours_to_fix, :open_now, :awaiting_verification
  json.root_causes @stats.root_causes.to_h
end
json.checks @checks do |check|
  json.merge! agent_ref(check)
  json.extract! check, :name, :kind, :url, :live, :every_days, :state
  json.client agent_ref(check.client)
  json.owner agent_user(check.owner)
end
json.ending_soon @expiring do |expectation|
  json.extract! expectation, :key, :label, :expected, :expires_on
  json.check agent_ref(expectation.check)
end
