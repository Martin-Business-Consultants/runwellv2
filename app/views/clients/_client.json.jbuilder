json.merge! agent_ref(client)
json.extract! client, :name, :status, :time_zone, :internal
json.time_zone_used client.zone.name
json.custom_fields client.custom_field_hash
