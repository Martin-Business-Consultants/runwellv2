json.summary pluralize(@todos.size, "todo")
json.work @todos.includes(:owner, :scope_item, :client, :contact, { assignments: :user }, :engagement), partial: "todos/todo", as: :todo
