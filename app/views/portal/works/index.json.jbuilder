json.summary "#{pluralize @works.size, term(:work).downcase} with #{client.name}"
json.works @works do |work|
  json.merge! portal_agent_ref(work)
  json.extract! work, :title
  json.label work.label_name
  json.state work.state
end
