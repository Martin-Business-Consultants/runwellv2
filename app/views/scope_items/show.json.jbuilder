json.summary "#{@item.description} (#{@item.delivery_state.humanize.downcase})"
json.scope_item do
  json.partial! "scope_items/scope_item", scope_item: @item
  json.work agent_ref(@work)
  json.tasks @tasks, partial: "tasks/task", as: :task
  json.notes @item.notes.recent.includes(:author), partial: "notes/note", as: :note
  json.documents @item.documents.recent.preloaded, partial: "documents/document", as: :document
end
