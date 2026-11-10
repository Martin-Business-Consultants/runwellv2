unread = portal_unread_task_ids
json.summary "#{pluralize @tasks.size, "task"} shared with you, #{@tasks.count { it.status != "done" }} not done yet, #{@tasks.count { unread.include?(it.id) }} with a message you haven't read"
json.tasks @tasks do |task|
  json.id task.id
  json.your_priority task.client_priority
  json.title task.title
  json.status task.client_status
  json.due_on task.due_on
  json.late task.late?
  json.unread_messages unread.include?(task.id)
  json.work(task.work && portal_agent_ref(task.work))
end
