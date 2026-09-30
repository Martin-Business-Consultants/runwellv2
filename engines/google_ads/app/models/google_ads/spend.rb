# One ad account's spend in one month.
#
# The grain is the month because that is the grain of the question: a client
# asking what their advertising cost means "in August", not "on the 14th". The
# current month's row is rewritten every night and carries `through` — the last
# date it actually covers — so "month to date" can say which date it is to.
module GoogleAds
  class Spend < ApplicationRecord
    self.table_name = "google_ads_spends"

    validates :customer_id, presence: true
    validates :month, presence: true, uniqueness: { scope: :customer_id }

    scope :for_account, ->(customer_id) { where(customer_id: Client.normalize_customer_id(customer_id)) }
    scope :chronological, -> { order(month: :asc) }
    scope :recent_first, -> { order(month: :desc) }
    scope :since, ->(month) { where(month: month..) }

    normalizes :customer_id, with: ->(value) { Client.normalize_customer_id(value) }

    # The newest month on record for each of these accounts, keyed by customer
    # id. One query for a list of services rather than one per row — and it is
    # the row that answers "is this account producing numbers at all", which is
    # the only question the settings page asks of it.
    def self.latest_by_account(customer_ids)
      ids = Array(customer_ids).filter_map { |id| Client.normalize_customer_id(id) }.uniq
      return {} if ids.empty?

      where(customer_id: ids).chronological.index_by(&:customer_id)
    end

    def current_month? = month == Date.current.beginning_of_month

    # "August 2026", or "September so far" for the month still running.
    def label
      current_month? ? "#{month.strftime("%B")} so far" : month.strftime("%B %Y")
    end

    def cost_per_click_cents
      return nil if clicks.to_i.zero?

      (cost_cents.to_f / clicks).round
    end

    def cost_per_conversion_cents
      return nil if conversions.to_f < 1

      (cost_cents / conversions).round
    end
  end
end
