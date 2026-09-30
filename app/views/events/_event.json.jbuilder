json.extract! event, :kind, :source, :occurred_at, :payload
json.by event.actor_name
json.via event.actor if event.source == "agent"
