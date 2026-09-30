module Factory
  # Hands the next piece of work to a runner. Work is taken earliest due date first, then in the
  # order it was queued (no priorities: a date says how urgent it is). Refuses, with the reason,
  # when the factory is at its run limit or over budget. Two runners can't take the same item:
  # the database allows one running run per item.
  class Queue
    Refusal = Data.define(:reason)

    def initialize(policy = Policy.current)
      @policy = policy
    end

    def claim!(runner:, user:)
      Run.expire_stale!
      return Refusal.new("The monthly budget is used up.") if @policy.over_budget?
      return Refusal.new("#{@policy.max_concurrent_runs} runs are already going, the limit.") if Run.running.count >= @policy.max_concurrent_runs

      candidates.each do |item|
        next unless item.claimable?

        return start!(item, runner: runner, user: user)
      rescue ActiveRecord::RecordNotUnique
        next
      end
      Refusal.new("Nothing is ready for an agent.")
    end

    def candidates
      Item.with_todo.includes(:runs).joins(:todo).where.not(todos: { status: %w[done in_review] })
        .order(Arel.sql("todos.due_on IS NULL, todos.due_on, factory_items.created_at"))
    end

    private
      def start!(item, runner:, user:)
        Run.transaction do
          run = item.runs.create!(todo: item.todo, claimed_by: user, runner: runner, attempt: item.attempts + 1,
            started_at: Time.current, lease_expires_at: @policy.lease_duration.from_now, heartbeat_at: Time.current)
          item.todo.update!(status: "in_progress") unless item.todo.status == "in_progress"
          item.todo.record_event!("factory.claimed", actor: user, source: "agent", payload: { runner: runner, attempt: run.attempt })
          run
        end
      end
  end
end
