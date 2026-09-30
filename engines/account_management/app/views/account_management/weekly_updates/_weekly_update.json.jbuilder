json.merge! agent_ref(weekly_update)
json.extract! weekly_update, :week_of, :sent_at
json.due_at weekly_update.due_at
json.sent weekly_update.sent?
json.on_time weekly_update.on_time?
json.user agent_user(weekly_update.user)
