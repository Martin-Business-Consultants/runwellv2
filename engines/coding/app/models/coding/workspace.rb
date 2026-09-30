module Coding
  # Everything someone (or an agent) needs to start a todo on their own machine: where the
  # code is and how to set it up, the branch to work on, and what was agreed, so the work is
  # measured against the scope the client approved rather than a guess.
  class Workspace
    attr_reader :todo

    def initialize(todo)
      @todo = todo
    end

    def engagement = todo.engagement
    def repositories = @repositories ||= Repository.for(todo)
    def source = Repository.source_for(todo)
    def branch_name = Branch.name_for(todo)
    def branches = todo.coding_branches.includes(:repository).index_by(&:repository_id)
    def branch_for(repository) = branches[repository.id]&.name || branch_name

    def clone_commands(repository)
      directory = repository.name.split("/").last
      [ "git clone #{repository.url} #{directory}", "cd #{[ directory, repository.path ].compact.join("/")}",
        "git switch #{branch_for(repository)} 2>/dev/null || git switch -c #{branch_for(repository)} origin/#{repository.default_branch}" ]
    end

    # The terms in force: the latest approved version as the client saw it, or nil before any
    # approval (then the draft's items are all there is, and they may still change).
    def agreed = engagement.current_version&.snapshot
    def agreed_items = engagement.agreed_items
    def draft = engagement.draft_version

    def notes = todo.notes.recent.includes(:author).limit(10)
    def commitments = engagement.commitments.open.ordered
    def documents = todo.documents.recent + engagement.documents.recent
  end
end
