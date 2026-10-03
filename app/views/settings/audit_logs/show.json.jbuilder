json.summary "#{@events.size} events#{" (the newest 500)" if @events.size == 500}: #{Settings::AuditLogsController::AREAS[@area].downcase}, #{Settings::AuditLogsController::PERIODS[@days].downcase}#{", by #{@person.display_name}" if @person}"
json.events @events do |event|
  json.partial! "events/event", event: event
  json.subject_type event.subject_type
  json.subject_id event.subject_id
  json.on audit_subject_name(event)
end
