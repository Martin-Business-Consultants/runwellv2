json.summary "#{@client.name} (#{@client.status})"
json.client do
  json.partial! "clients/client", client: @client
  json.contacts @client.contacts.active.ordered, partial: "contacts/contact", as: :contact
  json.works @client.works.ordered.includes(:client, :custom_values), partial: "works/work", as: :work
  json.open_tasks @client.tasks.open.includes(:owner, :scope_item, :client, :contact, :work, :custom_values, assignments: :user).order(:due_on, :position), partial: "tasks/task", as: :task
  json.notes @client.notes.recent.includes(:author).limit(20), partial: "notes/note", as: :note
  json.documents @client.documents.recent, partial: "documents/document", as: :document
end
