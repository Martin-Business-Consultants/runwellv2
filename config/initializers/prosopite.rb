# N+1 queries (Prosopite): every request is scanned in development and test (NPlusOneDetection). In
# development each one found is logged, to the Rails log and log/prosopite.log; in test it raises,
# so a request that loads records one by one fails its test (PROSOPITE_RAISE=0 logs them to
# log/prosopite.log instead, to see them all at once). Production never loads the gem.
if defined?(Prosopite)
  Rails.application.config.after_initialize do
    Prosopite.rails_logger = true
    Prosopite.raise = Rails.env.test? && ENV["PROSOPITE_RAISE"] != "0"
    Prosopite.prosopite_logger = !Prosopite.raise?
    Prosopite.min_n_queries = 2
    # Loops that query per record on purpose, so they aren't N+1s to fix:
    # - Agent::Resolver tries a name as exact, then prefix, then contains, stopping at a match
    # - a bulk action runs each record's own verb, one at a time (BulkAction)
    # - a status change re-places the task in its lists (positioning, TasksController#update; a
    #   decline marks it done, Task::Intake#decline!)
    # - erasing a piece of work destroys what hangs off each record
    Prosopite.allow_stack_paths = [ "app/models/agent/resolver.rb", "app/controllers/concerns/bulk_action.rb",
      "TasksController#update", "Tasks::StatusesController#update", "Task::Intake#decline!", "Work#erase!",
      # The board renders each column's first page (one query a column, a handful, on purpose).
      "app/views/tasks/board/_cards.html.erb" ]
  end
end
