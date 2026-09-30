module Factory
  # One attempt at an item by a runner. Claimed with a lease the runner renews with heartbeats;
  # a lease that runs out (the runner died) abandons the run and frees the work. Finishing
  # records what the agent did, where (branch, pull request, log) and what it cost, and moves
  # the todo: to in review on success, back to planned for another attempt, or to blocked with
  # a note once the attempts are used up.
  class Run < ::ApplicationRecord
    self.table_name = "factory_runs"

    STATUSES = %w[running succeeded failed abandoned cancelled].freeze
    OUTCOMES = %w[succeeded failed].freeze
    # Attempts that count against max_attempts. A cancelled run was a person's choice.
    COUNTED = %w[succeeded failed abandoned].freeze

    belongs_to :item, optional: true, inverse_of: :runs
    belongs_to :todo, class_name: "::Todo"
    belongs_to :claimed_by, class_name: "::User", optional: true

    validates :status, inclusion: { in: STATUSES }
    validates :runner, presence: true

    scope :running, -> { where(status: "running") }
    scope :recent, -> { order(started_at: :desc) }
    scope :stale, -> { running.where(lease_expires_at: ...Time.current) }

    def label = "Run #{id} on #{runner}"
    def running? = status == "running"
    def finished? = !running?
    def duration = ((finished_at || Time.current) - started_at).to_i
    def deadline = started_at + Policy.current.time_limit
    def past_deadline? = running? && Time.current > deadline + 5.minutes

    # Frees work whose runner stopped answering, or ran past its time limit.
    def self.expire_stale!
      stale.find_each { it.close!("abandoned", error: "The runner stopped reporting (its lease ran out).") }
      running.find_each { it.close!("failed", error: "Ran past the #{Policy.current.run_time_limit_minutes}-minute limit.") if it.past_deadline? }
    end

    def heartbeat!
      update!(heartbeat_at: Time.current, lease_expires_at: Policy.current.lease_duration.from_now)
    end

    def reportable_by?(user) = claimed_by_id == user&.id

    def finish!(outcome:, summary:, branch: nil, pull_request_url: nil, log_url: nil, cost_cents: nil, input_tokens: nil, output_tokens: nil)
      raise ArgumentError, "unknown outcome" unless OUTCOMES.include?(outcome)

      assign_attributes(branch: branch.presence, pull_request_url: pull_request_url.presence, log_url: log_url.presence,
        cost_cents: cost_cents.to_i, input_tokens: input_tokens.to_i, output_tokens: output_tokens.to_i)
      close!(outcome, summary: summary, error: (summary if outcome == "failed"))
    end

    def cancel!(by:)
      close!("cancelled", error: "Cancelled by #{by.display_name}.", actor: by)
    end

    # Ends the run and moves its todo on. Every way a run ends comes through here.
    def close!(status, summary: nil, error: nil, actor: claimed_by)
      transaction do
        update!(status: status, finished_at: Time.current, summary: summary.presence || self.summary, error: error)
        note = [ "Agent run #{status} on #{runner}", (summary.presence || error), (pull_request_url && "Pull request: #{pull_request_url}") ]
          .compact.map { it.strip.sub(/[.!?]*\z/, ".") }.join(" ")
        todo.notes.create!(body: note, kind: "internal", source: "agent", author: actor)
        record_on_code_plugin if branch || pull_request_url
        todo.update!(status: next_todo_status(status)) unless todo.status == "done"
        todo.record_event!("factory.#{status}", actor: actor, source: "agent",
          payload: { runner: runner, attempt: attempt, branch: branch, pull_request: pull_request_url, cost_cents: cost_cents }.compact)
      end
    end

    private
      def next_todo_status(status)
        case status
        when "succeeded" then "in_review"
        when "cancelled" then "planned"
        else item&.exhausted? ? "blocked" : "planned"
        end
      end

      def record_on_code_plugin
        return unless Runwell::Plugins.enabled?(:coding) && defined?(Coding::Branch)

        Coding::Branch.record!(todo, name: branch, pull_request_url: pull_request_url)
      end
  end
end
