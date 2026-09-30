json.summary "#{@update.user.display_name}, #{@update.label.downcase_first}: #{@update.sent? ? "sent #{l @update.sent_at, format: :short}#{", late" unless @update.on_time?}" : "draft, due #{l @update.due_at, format: :short}"}"
json.partial! "account_management/weekly_updates/weekly_update", weekly_update: @update
json.body agent_text(@update.body)
