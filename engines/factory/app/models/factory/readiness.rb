module Factory
  # Whether an agent can take a piece of work unattended, and if not, what a person must fix
  # first. Unattended work needs agreed scope to measure against, something to go on, a
  # repository to work in, and a client who allows agent work.
  class Readiness
    attr_reader :todo

    def initialize(todo)
      @todo = todo
    end

    def ready? = problems.empty?

    def problems
      @problems ||= [
        ("It’s done." if todo.status == "done"),
        ("It’s waiting for review." if todo.status == "in_review"),
        ("#{engagement.ref} is closed." if engagement.closed?),
        ("#{engagement.ref} has no approved agreement yet, so there’s no agreed scope to work to." unless engagement.current_version),
        ("It has no description or #{term(:scope_item).downcase} to say what to build." if todo.description.blank? && todo.scope_item.nil?),
        repository_problem,
        ("#{todo.client.name} doesn’t allow agent work (Settings → Factory)." unless Policy.current.client_allowed?(todo.client))
      ].compact
    end

    private
      def engagement = todo.engagement

      def term(key) = ::Setting.current.term(key)

      # The Code plugin says where the code is. Without it an agent has nowhere to work.
      def repository_problem
        if !Runwell::Plugins.enabled?(:coding)
          "Switch on the Code plugin and link a repository."
        elsif Coding::Repository.for(todo).none?
          "No repository is linked to it, #{engagement.ref} or #{todo.client.name}."
        end
      end
  end
end
