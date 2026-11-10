json.summary "#{pluralize @requests.size, "request"}, #{@requests.count { it.client_status == "received" }} not taken on yet"
json.requests @requests do |request_record|
  json.id request_record.id
  json.subject request_record.title
  json.received_at request_record.created_at
  json.due_on request_record.due_on
  json.status request_record.client_status
  json.work(request_record.work && portal_agent_ref(request_record.work))
end
