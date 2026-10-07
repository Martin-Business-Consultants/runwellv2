json.merge! agent_ref(todo)
json.extract! todo, :title, :status, :due_on, :client_visible
json.overdue todo.due_on.present? && todo.due_on < Date.current && todo.status != "done"
json.owner agent_user(todo.owner)
json.other_owners todo.other_owners.map { agent_user(it) }
json.engagement agent_ref(todo.engagement)
json.scope_item agent_ref(todo.scope_item)
json.custom_fields todo.custom_field_hash
