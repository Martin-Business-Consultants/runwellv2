messages = @task.notes.discussion.includes(:author).to_a
json.summary "#{@task.title}: #{@task.client_status_label.downcase}, #{pluralize messages.size, "message"}"
json.task do
  json.id @task.id
  json.title @task.title
  json.status @task.client_status
  json.due_on @task.due_on
  json.late @task.late?
  json.completed_at @task.completed_at
  json.your_priority @task.client_priority
  json.description agent_text(@task.description)
  json.work(@task.work && portal_agent_ref(@task.work))
  json.section @task.scope_item&.description
  json.asked_by @task.contact&.name
  json.with portal_task_people(@task)
  json.url portal_tasks_url(task: @task.id, status: "all")

  json.documents @task.documents.client_visible.includes(file_attachment: :blob) do |document|
    json.filename document.filename.to_s
    json.byte_size document.byte_size
    json.content_type document.content_type
    json.url rails_blob_url(document.file, disposition: :attachment)
  end

  json.discussion messages do |note|
    json.from note.author&.display_name || "The team"
    json.yours note.author_id == current_contact.id
    json.from_team !note.from_client?
    json.at note.occurred_at
    json.text agent_text(note.body)
  end
end
