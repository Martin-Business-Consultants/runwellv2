json.summary pluralize(@tasks.size, "task")
json.tasks @tasks.includes(:owner, :scope_item, :client, :contact, { assignments: :user }, :work), partial: "tasks/task", as: :task
