json.merge! agent_ref(scope_item)
json.extract! scope_item, :description, :internal_estimate
json.price money(scope_item.price_cents)
json.price_cents scope_item.price_cents
json.delivery_state scope_item.delivery_state
