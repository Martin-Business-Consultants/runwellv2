json.summary "#{pluralize(@requests.size, "request")} (#{@status})"
json.requests @requests, partial: "requests/request", as: :request_record
