json.merge! agent_ref(scope_item)
json.extract! scope_item, :description, :position
json.delivery_state scope_item.delivery_state
