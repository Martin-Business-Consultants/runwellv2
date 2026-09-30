json.merge! agent_ref(meeting)
json.extract! meeting, :title, :state, :starts_at, :agenda_sent_at, :agenda_sent_via, :recap_sent_at, :recap_sent_via, :cancelled_at
json.starts_at_for_client meeting.starts_at.in_time_zone(meeting.client.zone)
json.client_time_zone meeting.client.zone.name
json.agenda_due_at meeting.agenda_due_at
json.recap_due_at meeting.recap_due_at
json.agenda_on_time meeting.agenda_on_time
json.recap_on_time meeting.recap_on_time
json.client agent_ref(meeting.client)
json.engagement agent_ref(meeting.engagement)
json.owner agent_user(meeting.owner)
