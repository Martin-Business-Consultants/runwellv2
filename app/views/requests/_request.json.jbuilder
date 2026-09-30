json.merge! agent_ref(request_record)
json.extract! request_record, :subject, :source, :status, :received_at, :dismissed_reason
json.from request_record.requester_name
json.client agent_ref(request_record.client)
json.promoted_to agent_ref(request_record.promoted)
