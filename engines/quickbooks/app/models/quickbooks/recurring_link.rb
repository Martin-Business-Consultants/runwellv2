module Quickbooks
  # A service tied to a QuickBooks recurring invoice template, so the recurring revenue the
  # client agreed to is the recurring revenue QuickBooks bills. Runwell keeps the template in
  # step (an approved revision changes its amount, closing the service stops it); the sync
  # flags a template someone changed in QuickBooks so it no longer matches what was agreed.
  class RecurringLink < ::ApplicationRecord
    self.table_name = "quickbooks_recurring_links"

    CADENCES = { "weekly" => [ "Weekly", 1 ], "monthly" => [ "Monthly", 1 ], "quarterly" => [ "Monthly", 3 ] }.freeze

    belongs_to :engagement, class_name: "::Engagement"
    belongs_to :contact, class_name: "::Contact", optional: true

    validates :qbo_id, presence: true
    validates :engagement_id, uniqueness: { message: "already has a recurring invoice" }

    scope :drifting, -> { where.not(drift: nil) }

    def in_sync? = drift.nil?
    UNITS = { "Daily" => "day", "Weekly" => "week", "Monthly" => "month", "Yearly" => "year" }.freeze

    # "every month", "every 3 months".
    def schedule_label
      unit = UNITS[interval_type] or return nil
      num_interval.to_i > 1 ? "every #{num_interval} #{unit.pluralize}" : "every #{unit}"
    end
    def label = "#{engagement.ref} recurring invoice"

    # What QuickBooks should hold for this service: the approved amount per period and cadence,
    # active while the service is open.
    def expected
      version = engagement.current_version
      interval, every = CADENCES.fetch(version&.cadence.to_s, CADENCES["monthly"])
      { amount_cents: version&.amount_cents.to_i, interval_type: interval, num_interval: every, active: !engagement.closed? }
    end

    # Remembers what QuickBooks said and whether it matches what was agreed.
    def observe!(template)
      schedule = template.dig("RecurringInfo", "ScheduleInfo") || {}
      update!(sync_token: template["SyncToken"], name: template.dig("RecurringInfo", "Name"),
        amount_cents: (template["TotalAmt"].to_f * 100).round, interval_type: schedule["IntervalType"],
        num_interval: schedule["NumInterval"], active: template.dig("RecurringInfo", "Active") != false,
        next_on: schedule["NextDate"].presence, synced_at: Time.current, drift: nil)
      update!(drift: drift_from(expected))
    end

    private
      def drift_from(wanted)
        differences = []
        differences << "QuickBooks bills #{Money.format(amount_cents)}, the client agreed #{Money.format(wanted[:amount_cents])}" if amount_cents != wanted[:amount_cents]
        differences << "QuickBooks bills #{schedule_label}, the agreement says #{engagement.current_version&.cadence}" if [ interval_type, num_interval.to_i ] != [ wanted[:interval_type], wanted[:num_interval] ]
        differences << (active ? "the service is closed but QuickBooks still bills it" : "QuickBooks stopped billing an open service") if active != wanted[:active]
        differences.join("; ").presence
      end
  end
end
