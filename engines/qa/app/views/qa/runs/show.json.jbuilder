json.merge! agent_ref(@run)
json.summary "#{@run.check.name}: #{@run.summary}"
json.extract! @run, :status, :source, :reporter, :evidence_url, :http_status, :created_at
json.notes agent_text(@run.notes)
json.tested_by agent_user(@run.user)
json.check agent_ref(@run.check)
json.results @run.results do |result|
  json.extract! result, :key, :label, :expected, :actual, :passed
end
