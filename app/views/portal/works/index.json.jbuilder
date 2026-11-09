json.summary "#{pluralize @works.size, term(:work).downcase} with #{client.name} (#{@state})"
json.works @works do |work|
  json.merge! portal_agent_ref(work)
  json.extract! work, :title
  json.your_priority work.client_priority
  json.label work.label_name
  json.state work.state
end
