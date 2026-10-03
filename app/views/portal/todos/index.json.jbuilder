json.summary "#{pluralize @todos.size, "piece"} of work shared with you, #{@todos.count { it.status != "done" }} not done yet"
json.work @todos do |todo|
  json.title todo.title
  json.status todo.status
  json.due_on todo.due_on
  json.engagement portal_agent_ref(todo.engagement)
end
