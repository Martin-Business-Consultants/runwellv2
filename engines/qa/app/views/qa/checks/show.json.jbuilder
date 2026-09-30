latest = @check.latest_results
json.merge! agent_ref(@check)
json.summary "#{@check.name} (#{@check.client.name}): #{@check.state}, #{pluralize(@check.expectations.size, "expectation")}, #{@issues.size} open issues"
json.extract! @check, :name, :kind, :url, :live, :every_days, :state, :archived_at, :retest_after
json.instructions agent_text(@check.instructions)
json.client agent_ref(@check.client)
json.engagement agent_ref(@check.engagement)
json.owner agent_user(@check.owner)
json.report_url qa_report_address(@check)
json.expectations @check.expectations do |expectation|
  result = latest[expectation.id]
  json.extract! expectation, :id, :key, :label, :expected, :match, :expires_on, :note
  json.rule expectation.rule
  json.kind expectation.value? ? "value" : "step"
  json.latest(result && { passed: result.passed, actual: result.actual, tested_at: result.created_at, by: result.run.tester_label })
end
json.open_issues @issues, partial: "qa/issues/issue", as: :issue
json.recent_tests @runs do |run|
  json.merge! agent_ref(run)
  json.extract! run, :status, :source, :created_at
  json.summary run.summary
  json.by run.tester_label
end
