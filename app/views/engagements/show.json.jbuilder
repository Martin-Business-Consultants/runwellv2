json.summary "#{@engagement.ref} #{@engagement.title}: #{@engagement.state_label.downcase}"
json.engagement do
  json.partial! "engagements/engagement", engagement: @engagement
  json.description agent_text(@engagement.description)
  json.estimate_notes agent_text(@engagement.estimate_notes)
  json.agreement_versions @engagement.agreement_versions.order(:number), partial: "agreement_versions/agreement_version", as: :agreement_version
  json.work @engagement.todos.includes(:owner, :scope_item, :custom_values, assignments: :user).order(:due_on, :position), partial: "todos/todo", as: :todo
  json.commitments @engagement.commitments.ordered, partial: "commitments/commitment", as: :commitment
  json.notes @engagement.notes.recent.includes(:author).limit(20), partial: "notes/note", as: :note
  json.documents @engagement.documents.recent, partial: "documents/document", as: :document
  json.history @engagement.events.order(occurred_at: :desc).limit(20), partial: "events/event", as: :event
end
