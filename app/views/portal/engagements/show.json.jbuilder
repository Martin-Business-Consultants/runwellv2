json.summary "#{@engagement.ref} #{@engagement.title}: #{@engagement.state_label.downcase}"
json.engagement do
  json.merge! portal_agent_ref(@engagement)
  json.extract! @engagement, :title
  json.label @engagement.label_name
  json.state @engagement.state
  json.per_period @engagement.recurring?
  json.description agent_text(@engagement.description)

  json.sections @engagement.scope_items do |item|
    json.name item.description
    json.delivery item.delivery_state
  end

  json.work @engagement.todos.client_visible.order(:due_on) do |todo|
    json.title todo.title
    json.status todo.status
    json.due_on todo.due_on
  end

  json.documents @engagement.client_documents.includes(file_attachment: :blob) do |document|
    json.filename document.filename.to_s
    json.byte_size document.byte_size
    json.content_type document.content_type
    json.url rails_blob_url(document.file, disposition: :attachment)
  end
end
