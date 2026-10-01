json.merge! agent_ref(engagement)
json.extract! engagement, :title, :label, :shape
json.type_name engagement.label_name
json.state engagement.state
json.internal engagement.internal?
json.agreed_amount money(engagement.agreed_amount_cents)
json.agreed_amount_cents engagement.agreed_amount_cents
json.client agent_ref(engagement.client)
json.closed engagement.closed?
json.custom_fields engagement.custom_field_hash
