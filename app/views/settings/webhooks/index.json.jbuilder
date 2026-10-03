json.summary @endpoints.any? ? "#{@endpoints.size} webhooks, #{@endpoints.count(&:active?)} on" : "No webhooks. An owner adds them in Settings > Webhooks."
json.webhooks @endpoints do |endpoint|
  json.extract! endpoint, :id, :url, :description, :kinds, :include_security, :active, :failures_in_a_row, :last_delivered_at
end
