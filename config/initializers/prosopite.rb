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
    # - approving creates one todo per scope item, each placed in its list (positioning)
    # - a status change re-places the todo in its lists (positioning, TodosController#update)
    # - deleting a draft or erasing an engagement destroys what hangs off each record
    Prosopite.allow_stack_paths = [ "app/models/agent/resolver.rb", "app/controllers/concerns/bulk_action.rb",
      "AgreementVersion::Lifecycle#spawn_todos!", "TodosController#update", "AgreementVersionsController#destroy",
      "Engagement#erase!" ]
  end

  # Prosopite tells queries apart with pg_query, a Postgres parser, which can't read SQLite's ?
  # placeholders: every fingerprint failed and Prosopite raised the query itself. Postgres's $1 in
  # their place reads the same for fingerprinting.
  Prosopite.singleton_class.prepend(Module.new do
    def fingerprint(query) = super(query.gsub(/(?<![\w'"])\?(?![\w'"])/, "$1"))
  end)
end
