json.summary "#{@work.ref} #{@work.title}: #{@work.state_label.downcase}"
json.work do
  json.merge! portal_agent_ref(@work)
  json.extract! @work, :title
  json.label @work.label_name
  json.state @work.state
  json.per_period @work.recurring?
  json.description agent_text(@work.description)

  json.sections @work.scope_items do |item|
    json.name item.description
    json.delivery item.delivery_state
  end

  json.tasks @work.tasks.client_visible.order(:due_on) do |task|
    json.title task.title
    json.status task.status
    json.due_on task.due_on
  end

  json.documents @work.client_documents.includes(file_attachment: :blob) do |document|
    json.filename document.filename.to_s
    json.byte_size document.byte_size
    json.content_type document.content_type
    json.url rails_blob_url(document.file, disposition: :attachment)
  end
end
