json.summary @connection.connected? ? "Connected to Google Ads" : "Not connected: #{@connection.blocker}"
json.connected @connection.connected?
json.blocker @connection.blocker
json.last_error @connection.last_error
json.last_synced_at @connection.last_synced_at
json.last_sync @connection.last_sync_summary
json.alert_recipients @connection.alert_recipient_list
json.linked_accounts @links do |link|
  month = @latest[link.customer_id]
  json.customer_id link.formatted_customer_id
  json.label link.label
  json.stopped link.account&.blocked? || false
  json.engagement agent_ref(link.engagement)
  json.latest_month(month && { month: month.label, spend: money(month.cost_cents), leads: month.conversions.round(1) })
end
json.reachable_accounts(@accessible.map { |label, id| { label: label, customer_id: GoogleAds::Client.format_customer_id(id) } })
