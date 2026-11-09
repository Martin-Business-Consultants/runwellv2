json.merge! agent_ref(work)
json.extract! work, :title, :label, :shape, :cadence, :client_priority
json.type_name work.label_name
json.state work.state
json.state_label work.state_label
json.close_outcome work.close_outcome if work.closed?
json.internal work.internal?
json.client agent_ref(work.client)
json.closed work.closed?
json.custom_fields work.custom_field_hash
