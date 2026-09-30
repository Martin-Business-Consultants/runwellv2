json.summary "#{@todo.title} (#{@todo.status.humanize.downcase})"
json.todo do
  json.partial! "todos/todo", todo: @todo
  json.description agent_text(@todo.description)
  json.notes @todo.notes.recent.includes(:author), partial: "notes/note", as: :note
  json.documents @todo.documents.recent, partial: "documents/document", as: :document
  json.history @todo.events.order(occurred_at: :desc).limit(20), partial: "events/event", as: :event
end
