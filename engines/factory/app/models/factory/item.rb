module Factory
  # A todo handed to agents. Its state is read off the todo and its runs, never typed in:
  #   running  a runner holds it now
  #   review   an agent finished; a person checks it (the todo is in review)
  #   done     the todo is done
  #   failed   every attempt failed; a person has to look
  #   blocked  queued, but something has to be fixed before an agent can take it
  #   queued   waiting for the next free runner
  class Item < ::ApplicationRecord
    self.table_name = "factory_items"

    STATES = %w[queued blocked running review failed done].freeze

    belongs_to :todo, class_name: "::Todo"
    belongs_to :engagement, class_name: "::Engagement"
    belongs_to :client, class_name: "::Client"
    belongs_to :queued_by, class_name: "::User", optional: true
    has_many :runs, -> { order(:started_at) }, dependent: :nullify, inverse_of: :item

    before_validation { self.engagement ||= todo&.engagement; self.client ||= todo&.engagement&.client }

    scope :with_todo, -> { includes(todo: [ :owner, { engagement: :client } ]) }

    # Queues the todo, or queues it again (a retry starts its attempts afresh).
    def self.queue!(todo, by:, instructions: nil, source: Current.source || "app")
      item = find_or_initialize_by(todo: todo)
      item.update!(queued_by: by, instructions: instructions.presence || item.instructions, source: source, queued_at: Time.current)
      todo.record_event!("factory.queued", actor: by, source: source, payload: { instructions: instructions.presence }.compact) if item.previously_new_record?
      item
    end

    def state
      return "done" if todo.status == "done"
      return "running" if current_run
      return "review" if todo.status == "in_review"
      return "failed" if exhausted?

      readiness.ready? ? "queued" : "blocked"
    end

    def current_run = runs.detect(&:running?)
    def last_run = runs.last
    # Attempts since it was last queued, so handing it over again starts afresh.
    def attempts = runs.count { it.status.in?(Run::COUNTED) && it.started_at >= queued_at }
    def exhausted? = attempts >= Policy.current.max_attempts && last_run&.status.in?(Run::COUNTED) && last_run.started_at >= queued_at
    def readiness = @readiness ||= Readiness.new(todo)
    def claimable? = state == "queued"
    def cost_cents = runs.sum(&:cost_cents)
  end
end
