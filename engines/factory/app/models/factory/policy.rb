module Factory
  # How the factory runs, for the whole install (one row, Settings > Factory): how many runs at
  # once, how long a runner's lease lasts between heartbeats, how long one run may take, how many
  # attempts a piece of work gets, the monthly budget, whether an approval queues its work by
  # itself, and which clients never get agent work.
  class Policy < ::ApplicationRecord
    self.table_name = "factory_settings"

    validates :max_concurrent_runs, numericality: { only_integer: true, in: 1..50 }
    validates :lease_minutes, numericality: { only_integer: true, in: 2..120 }
    validates :run_time_limit_minutes, numericality: { only_integer: true, in: 5..720 }
    validates :max_attempts, numericality: { only_integer: true, in: 1..10 }
    validates :monthly_budget_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

    def self.current = first_or_create!

    def lease_duration = lease_minutes.minutes
    def time_limit = run_time_limit_minutes.minutes

    def client_allowed?(client) = !Array(blocked_client_ids).map(&:to_i).include?(client.id)

    def spent_this_month_cents = Run.where(started_at: Time.current.all_month).sum(:cost_cents)

    def over_budget? = monthly_budget_cents.present? && spent_this_month_cents >= monthly_budget_cents
  end
end
