json.summary "#{@item.description} (#{@item.delivery_state.humanize.downcase})"
json.scope_item do
  json.partial! "scope_items/scope_item", scope_item: @item
  json.engagement agent_ref(@engagement)
  json.agreement_version agent_ref(@item.agreement_version)
  json.work @todos, partial: "todos/todo", as: :todo
  json.notes @item.notes.recent.includes(:author), partial: "notes/note", as: :note
  json.documents @item.documents.recent, partial: "documents/document", as: :document
end
