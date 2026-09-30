json.summary @connection.connected? ? "Connected to #{@connection.company_name || "QuickBooks"}#{@connection.blocker ? "; can’t invoice: #{@connection.blocker}" : ""}" : "Not connected: #{@connection.blocker}"
json.connected @connection.connected?
json.company_name @connection.company_name
json.environment @connection.environment
json.blocker @connection.blocker
json.last_error @connection.last_error
json.last_synced_at @connection.last_synced_at
json.last_sync @connection.last_sync_summary
json.default_item(@connection.default_item_id && { id: @connection.default_item_id, name: @connection.default_item_name })
json.items(@items.map { { id: it["Id"], name: it["Name"] } })
json.linked_customers @customers
json.recurring_invoices @recurring
