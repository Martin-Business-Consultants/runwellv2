json.summary "#{pluralize @tasks.size, "task"} shared with you, #{@tasks.count { it.status != "done" }} not done yet"
json.tasks @tasks do |task|
  json.title task.title
  json.status task.status
  json.due_on task.due_on
  json.work(task.work && portal_agent_ref(task.work))
end
