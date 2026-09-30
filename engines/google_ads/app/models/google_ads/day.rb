# One ad account, one day.
#
# The grain every chart in a PPC report is drawn at. The derived metrics live
# here rather than in the page, and every one of them guards its denominator —
# an account with no clicks has no cost per click, and rendering that as $0.00
# says "clicks are free" when the truth is "there were none".
#
# Nil, not zero, is the answer to an undefined ratio throughout. The portal
# renders nil as an em dash, and the difference between "nothing happened" and
# "this cannot be computed" is exactly what a client misreads.
module GoogleAds
  class Day < ApplicationRecord
    self.table_name = "google_ads_days"

    validates :customer_id, presence: true
    validates :date, presence: true, uniqueness: { scope: :customer_id }

    normalizes :customer_id, with: ->(value) { Client.normalize_customer_id(value) }

    scope :for_account, ->(customer_id) { where(customer_id: Client.normalize_customer_id(customer_id)) }
    scope :chronological, -> { order(date: :asc) }
    scope :in_month, ->(month) { where(date: month.beginning_of_month..month.end_of_month) }
    scope :between, ->(from, to) { where(date: from..to) }

    # --- derived, for one row -------------------------------------------------

    def cost_per_click_cents = clicks.to_i.positive? ? (cost_cents.to_f / clicks).round : nil

    def click_through_rate = impressions.to_i.positive? ? clicks.to_f / impressions : nil

    def conversion_rate = clicks.to_i.positive? ? conversions.to_f / clicks : nil

    def cost_per_conversion_cents = conversions.to_f.positive? ? (cost_cents / conversions).round : nil

    # --- derived, for a set of rows ------------------------------------------
    #
    # Totalled from the components, never averaged from the days. A month's
    # click-through rate is its clicks over its impressions; averaging thirty
    # daily percentages weights a Tuesday with four impressions the same as a
    # Monday with four thousand, and reports the wrong number with confidence.
    def self.summarize(rows)
      rows = rows.to_a
      cost = rows.sum { |row| row.cost_cents.to_i }
      clicks = rows.sum { |row| row.clicks.to_i }
      impressions = rows.sum { |row| row.impressions.to_i }
      conversions = rows.sum { |row| row.conversions.to_f }

      {
        days: rows.size,
        cost_cents: cost,
        clicks: clicks,
        impressions: impressions,
        conversions: conversions,
        conversions_value_cents: rows.sum { |row| row.conversions_value_cents.to_i },
        cost_per_click_cents: (clicks.positive? ? (cost.to_f / clicks).round : nil),
        click_through_rate: (impressions.positive? ? clicks.to_f / impressions : nil),
        conversion_rate: (clicks.positive? ? conversions / clicks : nil),
        cost_per_conversion_cents: (conversions.positive? ? (cost / conversions).round : nil),
        search_impression_share: average_impression_share(rows)
      }
    end

    # Impression share is a ratio Google reports per day and we cannot rebuild:
    # the denominator (impressions we were eligible for) never comes back. So it
    # is a mean of the days that HAVE one, weighted by that day's impressions —
    # the closest honest answer — and nil when no day has one, rather than a
    # zero that reads as "you captured none of your market".
    def self.average_impression_share(rows)
      known = rows.select { |row| row.search_impression_share.present? }
      return nil if known.empty?

      weight = known.sum { |row| row.impressions.to_i }
      return known.sum(&:search_impression_share) / known.size if weight.zero?

      known.sum { |row| row.search_impression_share * row.impressions.to_i } / weight
    end
  end
end
