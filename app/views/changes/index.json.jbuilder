json.summary(if @events.empty?
  "Nothing new#{" for #{(@engagement || @client).try(:ref) || @client&.name}" if @engagement || @client}."
else
  "#{pluralize @events.size, "change"}#{", and more: call again with after: #{@cursor}" if @more}."
end)
json.cursor @cursor
json.more @more
json.changes @events do |event|
  json.id event.id
  json.what event_title(event)
  json.kind event.kind
  json.details event_details(event).presence
  json.at event.occurred_at
  json.by event.actor_name
  json.source event.source_label
  json.subject agent_ref(event.subject)
end
