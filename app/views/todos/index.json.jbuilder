json.summary pluralize(@todos.size, "todo")
json.work @todos.includes(:owner, :scope_item, engagement: :client), partial: "todos/todo", as: :todo
