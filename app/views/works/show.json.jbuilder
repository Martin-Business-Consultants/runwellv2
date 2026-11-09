json.summary "#{@work.ref} #{@work.title}: #{@work.state_label.downcase}"
json.work do
  json.partial! "works/work", work: @work
  json.description agent_text(@work.description)
  json.sections @work.scope_items, partial: "scope_items/scope_item", as: :scope_item
  json.tasks @work.tasks.includes(:owner, :scope_item, :client, :contact, :work, :custom_values, assignments: :user).order(:due_on, :position), partial: "tasks/task", as: :task
  json.notes @work.notes.recent.includes(:author).limit(20), partial: "notes/note", as: :note
  json.documents @work.documents.recent.preloaded, partial: "documents/document", as: :document
  json.history @work.events.order(occurred_at: :desc).limit(20), partial: "events/event", as: :event
end
