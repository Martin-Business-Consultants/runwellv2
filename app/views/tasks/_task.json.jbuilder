json.merge! agent_ref(task)
json.extract! task, :title, :status, :due_on, :client_visible
json.overdue task.due_on.present? && task.due_on < Date.current && task.status != "done"
json.owner agent_user(task.owner)
json.other_owners task.other_owners.map { agent_user(it) }
json.work agent_ref(task.work)
json.client agent_ref(task.client)
json.request task.request?
json.requested_by(task.contact ? agent_ref(task.contact) : task.requester_name)
json.source task.source
json.scope_item agent_ref(task.scope_item)
json.custom_fields task.custom_field_hash
