json.summary "#{pluralize(@updates.size, "weekly update")}; this week’s is #{@this_week&.sent? ? "sent" : @this_week ? "a draft" : "not started"}"
json.weekly_updates @updates, partial: "account_management/weekly_updates/weekly_update", as: :weekly_update
