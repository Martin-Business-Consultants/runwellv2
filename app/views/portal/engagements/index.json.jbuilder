json.summary "#{pluralize @engagements.size, term(:engagement).downcase} with #{client.name}#{"; #{@engagements.count(&:pending_version)} awaiting your decision" if @engagements.any?(&:pending_version)}"
json.engagements @engagements do |engagement|
  json.merge! portal_agent_ref(engagement)
  json.extract! engagement, :title
  json.label engagement.label_name
  json.state engagement.state
  json.awaiting_your_decision engagement.pending_version.present?
end
