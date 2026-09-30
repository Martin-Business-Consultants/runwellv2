module Factory
  # What the factory needs a person for, on home: work every attempt failed on, work agents
  # finished that waits for review, and queued work something is blocking.
  module Attention
    def self.items
      return [] unless Runwell::Plugins.enabled?(:factory)

      Run.expire_stale!
      Item.with_todo.includes(:runs).select { it.state.in?(%w[failed review blocked]) }
        .sort_by { [ %w[failed blocked review].index(it.state), it.todo.due_on || Date.new(9999) ] }
    end
  end
end
