pending = client.engagements.includes(agreement_versions: :approval).select(&:pending_version)
json.summary "You act for #{current_contact.name} at #{client.name}#{"; #{pluralize pending.size, "agreement"} awaiting a decision" if pending.any?}."
json.me do
  json.name current_contact.name
  json.email current_contact.email
  json.company client.name
  json.can_decide_agreements current_contact.can_approve?
  json.agents_may_decide Setting.current.client_agent_approvals?
  json.time_zone Time.zone.name
end
json.agency Setting.current.brand_name
json.awaiting_decision pending.map { portal_agent_ref(it) }
json.read_only Current.access_token&.read_only? || false
