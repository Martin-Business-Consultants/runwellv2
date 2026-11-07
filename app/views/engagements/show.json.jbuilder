json.summary "#{@engagement.ref} #{@engagement.title}: #{@engagement.state_label.downcase}"
json.engagement do
  json.partial! "engagements/engagement", engagement: @engagement
  json.description agent_text(@engagement.description)
  json.sections @engagement.scope_items, partial: "scope_items/scope_item", as: :scope_item
  json.work @engagement.todos.includes(:owner, :scope_item, :client, :contact, :engagement, :custom_values, assignments: :user).order(:due_on, :position), partial: "todos/todo", as: :todo
  json.notes @engagement.notes.recent.includes(:author).limit(20), partial: "notes/note", as: :note
  json.documents @engagement.documents.recent, partial: "documents/document", as: :document
  json.history @engagement.events.order(occurred_at: :desc).limit(20), partial: "events/event", as: :event
end
