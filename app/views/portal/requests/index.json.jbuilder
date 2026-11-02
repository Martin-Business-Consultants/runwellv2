json.summary "#{pluralize @requests.size, "request"}, #{@requests.count(&:request?)} not taken on yet"
json.requests @requests do |request_record|
  json.id request_record.id
  json.subject request_record.title
  json.received_at request_record.created_at
  json.status portal_request_status(request_record).downcase
end
