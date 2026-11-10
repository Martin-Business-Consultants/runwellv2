json.summary @shifts.empty? ? "Nobody's on the Intake schedule: every owner and manager hears each client request as it comes in." : "#{@shifts.size} on the Intake schedule (times in #{Time.zone.name})."
json.time_zone Time.zone.name
json.shifts @shifts do |shift|
  json.id shift.id
  json.user agent_ref(shift.user)
  json.extract! shift, :mode, :days, :sources
  if shift.digest?
    json.digest_minutes shift.digest_minutes
    json.digest_at shift.digest_minutes.map { IntakeShift.clock(it) }
  else
    json.extract! shift, :from_minute, :to_minute
    json.from IntakeShift.clock(shift.from_minute)
    json.to IntakeShift.clock(shift.to_minute)
  end
  json.description "#{IntakeShift::MODES[shift.mode]}, #{shift.when_label}"
end
