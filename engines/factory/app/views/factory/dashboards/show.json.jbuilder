running = @items.fetch("running", [])
json.summary "#{running.size} running, #{@queue.size} queued, #{%w[failed blocked review].sum { @items.fetch(it, []).size }} need a person"
json.spent_this_month money(@policy.spent_this_month_cents)
json.spent_this_month_cents @policy.spent_this_month_cents
json.monthly_budget_cents @policy.monthly_budget_cents
json.running running.map(&:current_run), partial: "factory/runs/run", as: :run
json.queue @queue do |item|
  json.todo { json.partial! "todos/todo", todo: item.todo }
  json.queued_by agent_user(item.queued_by)
  json.attempts item.attempts
end
%w[failed blocked review].each do |state|
  json.set! state, @items.fetch(state, []) do |item|
    json.todo agent_ref(item.todo)
    json.problems item.readiness.problems if state == "blocked"
    json.last_run agent_ref(item.last_run)
  end
end
json.recent @recent, partial: "factory/runs/run", as: :run
