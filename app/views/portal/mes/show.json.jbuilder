json.summary "You act for #{current_contact.name} at #{client.name}."
json.me do
  json.name current_contact.name
  json.email current_contact.email
  json.company client.name
  json.can_approve current_contact.can_approve?
  json.time_zone Time.zone.name
end
json.business Setting.current.brand_name
json.read_only Current.access_token&.read_only? || false
