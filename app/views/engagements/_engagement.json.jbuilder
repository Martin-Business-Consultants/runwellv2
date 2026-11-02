json.merge! agent_ref(engagement)
json.extract! engagement, :title, :label, :shape
json.type_name engagement.label_name
json.state engagement.state
json.state_label engagement.state_label
json.close_outcome engagement.close_outcome if engagement.closed?
json.internal engagement.internal?
json.client agent_ref(engagement.client)
json.closed engagement.closed?
json.custom_fields engagement.custom_field_hash
