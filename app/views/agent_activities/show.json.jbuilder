json.summary "#{@events.size} things agents did#{" (the newest 500)" if @events.size == 500}: #{agent_activity_whose_label(@person, @whose)}, #{AgentActivitiesController::PERIODS[@days].downcase}"
json.events @events do |event|
  json.partial! "events/event", event: event
  json.for agent_user(event.actor_user&.person)
  json.subject_type event.subject_type
  json.subject_id event.subject_id
  json.on audit_subject_name(event)
end
