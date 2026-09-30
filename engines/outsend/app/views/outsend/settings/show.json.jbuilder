source = Outsend::Connection.key_source
json.summary source ? "Mail goes through Outsend (key from #{source})" : "No Outsend key: mail uses the server's SMTP settings"
json.active source.present?
json.key_source source
json.sender Setting.current.mail_sender
json.last_delivered_at @connection.last_delivered_at
json.delivered_count @connection.delivered_count
json.last_error @connection.last_error
json.last_error_at @connection.last_error_at
