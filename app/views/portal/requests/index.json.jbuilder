json.summary "#{pluralize @requests.size, "request"}, #{@requests.count(&:open?)} still open"
json.requests @requests do |request_record|
  json.id request_record.id
  json.subject request_record.subject
  json.received_at request_record.received_at
  json.status(case request_record.status
  when "open" then "open: not dealt with yet"
  when "promoted" then "taken on"
  else "closed#{": #{request_record.dismissed_reason}" if request_record.dismissed_reason.present?}"
  end)
end
