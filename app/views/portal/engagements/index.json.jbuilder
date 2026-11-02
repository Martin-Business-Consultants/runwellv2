json.summary "#{pluralize @engagements.size, term(:engagement).downcase} with #{client.name}"
json.engagements @engagements do |engagement|
  json.merge! portal_agent_ref(engagement)
  json.extract! engagement, :title
  json.label engagement.label_name
  json.state engagement.state
end
