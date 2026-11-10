json.summary "#{pluralize @tasks.size, "thing"} waiting in intake"
json.tasks @tasks do |task|
  json.partial! "tasks/task", task: task
  json.came_in task.created_at
  json.from intake_source_label(task)
  json.needs [ ("owner" unless task.owner_id), ("work" unless task.work_id) ].compact
end
