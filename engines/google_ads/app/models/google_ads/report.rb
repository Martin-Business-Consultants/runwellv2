# The monthly PPC report for one ad account, as data: spend, leads and cost per lead, then
# clicks, impressions, click-through rate, cost per click, conversion rate and impression
# share, each against the same stretch of last month, plus the daily and monthly series
# the charts are drawn from.
#
# Each measure gets its own axis. The only two series sharing one are click-through and
# conversion rate, which are both percentages and genuinely comparable; a dual-axis chart
# invents a correlation the data doesn't contain.
#
# Money is integer cents, rates are fractions of 1 (0.0894, not 8.94), and an undefined ratio
# is nil rather than zero: a month with no clicks has no cost per click, and "$0.00" would
# say clicks were free. There is no management fee here: the core has no money, and ad spend
# is the client's own money at Google.
module GoogleAds
  class Report
    # A year of months to page back through, which is as far as the sync keeps.
    MONTHS = 12

    def initialize(customer_id, month: nil)
      @customer_id = Client.normalize_customer_id(customer_id)
      @month = (month || Date.current).to_date.beginning_of_month
    end

    attr_reader :customer_id, :month

    def self.parse_month(value)
      Date.strptime(value.to_s, "%Y-%m")
    rescue ArgumentError, TypeError
      nil
    end

    def account = @account ||= Account.find_by(customer_id: customer_id)
    def current_month? = month == Date.current.beginning_of_month
    def month_name = current_month? ? "#{month.strftime("%B")} so far" : month.strftime("%B %Y")

    # The days this month, in order: every chart's spine.
    def days
      @days ||= Day.for_account(customer_id).in_month(month).chronological.to_a
    end

    # Nothing has ever been synced for this month, which is not the same as a month that ran
    # and spent nothing.
    def any? = days.any?

    def totals = @totals ||= Day.summarize(days)

    # Last month's same figures, like for like: for the month still running, the same DAYS
    # of last month, not all of it. Fifteen days against thirty-one reads as a collapse.
    def previous_totals
      @previous_totals ||= Day.summarize(Day.for_account(customer_id).between(previous_period_start, previous_period_end).chronological)
    end

    def previous_period_start = month.prev_month.beginning_of_month

    def previous_period_end
      return month.prev_month.end_of_month unless current_month?

      [ previous_period_start + (Date.current.day - 1), month.prev_month.end_of_month ].min
    end

    # What the changes are against, in the client's words.
    def comparison_label
      return "on last month" unless current_month?

      days = Date.current.day
      "on the first #{days} #{"day".pluralize(days)} of #{month.prev_month.strftime("%B")}"
    end

    # Proportional change against the comparison, or nil where there is none to make (every
    # change from zero is infinite).
    def change_in(key)
      now = totals[key]
      before = previous_totals[key]
      return nil if now.nil? || before.nil? || before.to_f.zero?

      (now.to_f - before) / before
    end

    def comparable? = previous_totals[:days].positive?

    # Every day of the month, including the ones with no row, so a gap draws as a gap.
    def series
      by_date = days.index_by(&:date)
      last = current_month? ? Date.current : month.end_of_month

      (month..last).map do |date|
        row = by_date[date]
        {
          date: date,
          label: date.strftime("%-d"),
          full_label: date.strftime("%b %-d"),
          cost_cents: row&.cost_cents.to_i,
          clicks: row&.clicks.to_i,
          impressions: row&.impressions.to_i,
          conversions: row&.conversions.to_f&.round(1) || 0.0,
          click_through_rate: row&.click_through_rate,
          conversion_rate: row&.conversion_rate,
          search_impression_share: row&.search_impression_share
        }
      end
    end

    # The months held, newest first, for the picker. Only months we have.
    def available_months
      earliest = Day.for_account(customer_id).minimum(:date)
      return [ Date.current.beginning_of_month ] if earliest.nil?

      floor = [ earliest.beginning_of_month, (MONTHS - 1).months.ago.to_date.beginning_of_month ].max
      months = []
      cursor = Date.current.beginning_of_month
      while cursor >= floor
        months << cursor
        cursor = cursor.prev_month
      end
      months
    end

    # Month-by-month totals across the window.
    def monthly_trend
      Spend.for_account(customer_id).since((MONTHS - 1).months.ago.to_date.beginning_of_month).chronological.map do |record|
        {
          month: record.month,
          label: record.month.strftime("%b"),
          full_label: record.label,
          cost_cents: record.cost_cents.to_i,
          conversions: record.conversions.to_f.round(1),
          current: record.current_month?
        }
      end
    end
  end
end
