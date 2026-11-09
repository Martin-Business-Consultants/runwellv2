json.summary "#{@task.title} (#{@task.status.humanize.downcase})"
json.task do
  json.partial! "tasks/task", task: @task
  json.description agent_text(@task.description)
  json.notes @task.notes.recent.includes(:author), partial: "notes/note", as: :note
  json.documents @task.documents.recent.preloaded, partial: "documents/document", as: :document
  json.history @task.events.order(occurred_at: :desc).limit(20), partial: "events/event", as: :event
end
