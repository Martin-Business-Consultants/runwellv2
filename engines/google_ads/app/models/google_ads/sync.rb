# Pull Google Ads spend into Runwell, one ad account at a time.
#
# One GAQL query per account covers the whole window — Google returns a row per
# day and the months are added up here. A query per month would be thirteen
# round trips to learn what one returns, and thirteen chances for a nightly job
# to half-finish.
#
# Deliberately re-reads the months it already has rather than only the current
# one: Google restates recent spend for a few days after the fact (invalid
# clicks are credited back), so a month written once on the 1st is wrong by the
# 5th. Thirteen months is one API call either way.
module GoogleAds
  class Sync
    # A year of history plus the month in progress — the window a client thinks
    # in for "what have I been spending".
    MONTHS = 13

    def initialize(connection, client: nil)
      @connection = connection
      @client = client || Client.new(connection)
    end

    attr_reader :connection, :client

    # Every ad account an engagement is linked to, synced once each however many
    # engagements share it.
    #
    # One account failing must not cost the others their nightly refresh, so a
    # per-account failure is collected and the loop carries on. An AuthError is
    # the exception: it says the CONNECTION is dead, so every remaining account
    # would fail the same way, and it is raised for the caller to record once.
    def call
      accounts = Link.distinct.pluck(:customer_id)
      return { accounts: 0, months: 0, failed: 0, errors: [] } if accounts.empty?

      months = 0
      errors = []

      accounts.each do |customer_id|
        months += sync_account(customer_id)
      rescue Client::AuthError
        raise
      rescue Client::Error => e
        errors << "#{customer_id}: #{e.message}"
        Rails.logger.warn("[GoogleAds::Sync] customer=#{customer_id} #{e.class}: #{e.message}")
      end

      summary = { accounts: accounts.size, months: months, failed: errors.size, errors: errors.first(5) }
      if errors.empty?
        connection.note_sync!(summary)
      else
        # Synced, but not cleanly. The timestamp is still true and the error is
        # still worth showing — clearing one to record the other would hide half
        # of what happened.
        connection.update!(last_synced_at: Time.current, last_sync_summary: summary,
                           last_error: errors.first)
      end
      summary
    end

    # One account. Returns how many month rows it wrote.
    def sync_account(customer_id)
      digits = Client.normalize_customer_id(customer_id)
      return 0 if digits.blank?

      rows = client.search(digits, daily_cost_query)
      by_month = totals_by_month(rows)
      # An account that spent nothing still gets a zero row for the current
      # month, so the portal can say "nothing spent yet this month" rather than
      # rendering an em dash, which reads as "we don't know".
      by_month[current_month] ||= blank_month
      currency = account_currency(digits, rows)

      by_month.each do |month, totals|
        record = Spend.find_or_initialize_by(customer_id: digits, month: month)
        record.update!(totals.merge(
          currency_code: currency,
          # The window covered the whole month, so a month with no spend on its
          # last days is still covered through its last day. Taking the final
          # date that HAD spend would report a complete August as "through the
          # 28th", which reads as data still arriving.
          through: [ month.end_of_month, Date.current ].min,
          synced_at: Time.current
        ))
      end

      sync_days(digits, rows)
      sync_account_state(digits, currency)

      by_month.size
    end

    # The same rows Google already sent, kept instead of discarded.
    #
    # Upserted one day at a time rather than deleted-and-reinserted: a client
    # loading the report while the nightly job runs would otherwise catch the
    # window where their month is empty.
    def sync_days(customer_id, rows)
      rows.each do |row|
        date = parse_date(row.dig("segments", "date"))
        next if date.nil?

        metrics = row["metrics"] || {}
        record = Day.find_or_initialize_by(customer_id: customer_id, date: date)
        record.update!(
          cost_cents: Client.micros_to_cents(metrics["costMicros"]),
          clicks: metrics["clicks"].to_i,
          impressions: metrics["impressions"].to_i,
          conversions: metrics["conversions"].to_f,
          conversions_value_cents: (metrics["conversionsValue"].to_f * 100).round,
          # Absent, not zero, when Google withholds it — which it does below a
          # volume threshold. `to_f` on the missing key would write 0.0 and tell
          # a client they captured none of their market.
          search_impression_share: metrics["searchImpressionShare"]&.to_f
        )
      end
    end

    # The account itself: what Google calls it, and whether it is still serving.
    #
    # Deliberately after the spend rows are written. The alert email quotes last
    # month's spend to say how much advertising has stopped, and an email that
    # went out before the figures landed would quote the wrong number — or none.
    def sync_account_state(customer_id, currency)
      described = client.describe(customer_id)
      account = Account.find_or_initialize_by(customer_id: customer_id)
      account.descriptive_name = described[:name] if described&.dig(:name).present?
      account.currency_code = currency if currency.present?
      account.save!

      # No status means the describe call came back empty — the account is
      # unreadable, which is not the same as stopped, and is not worth an email.
      status = described&.dig(:status)
      return if status.blank?

      alert_stopped(account) if account.note_status!(status, synced_at: Time.current)
    end

    # One email per account per stoppage, to the addresses in Settings > Google Ads.
    # Staff also see stopped accounts on the home page, recipients or not.
    #
    # A failure to deliver must not fail the sync: the spend is already written,
    # and losing a night of every client's figures because one SMTP call timed
    # out is a worse outcome than a missed email.
    def alert_stopped(account)
      recipients = connection.alert_recipient_list
      if recipients.empty?
        Rails.logger.warn("[GoogleAds::Sync] #{account.customer_id} stopped serving and nobody is listed to tell")
        return
      end

      recipients.each { |recipient| AlertMailer.account_stopped(recipient, account).deliver_later }
      account.note_alerted!
    rescue StandardError => e
      Rails.logger.error("[GoogleAds::Sync] alert for #{account.customer_id} failed: #{e.class}: #{e.message}")
    end

    private

    def current_month = Date.current.beginning_of_month

    def window_start = (MONTHS - 1).months.ago.to_date.beginning_of_month

    # FROM customer, not FROM campaign: a campaign query misses spend on
    # campaigns that have since been removed, and a client's August bill
    # includes what August's campaigns cost whether or not they still exist.
    def daily_cost_query
      <<~GAQL
        SELECT
          segments.date,
          customer.currency_code,
          metrics.cost_micros,
          metrics.impressions,
          metrics.clicks,
          metrics.conversions,
          metrics.conversions_value,
          metrics.search_impression_share
        FROM customer
        WHERE segments.date BETWEEN '#{window_start.iso8601}' AND '#{Date.current.iso8601}'
        ORDER BY segments.date ASC
      GAQL
    end

    # A malformed date is skipped rather than raised on: one unreadable row must
    # not cost an account its whole month.
    def parse_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def totals_by_month(rows)
      rows.each_with_object({}) do |row, months|
        date = parse_date(row.dig("segments", "date"))
        next if date.nil?

        bucket = months[date.beginning_of_month] ||= blank_month
        metrics = row["metrics"] || {}
        bucket[:cost_cents]  += Client.micros_to_cents(metrics["costMicros"])
        bucket[:impressions] += metrics["impressions"].to_i
        bucket[:clicks]      += metrics["clicks"].to_i
        bucket[:conversions] += metrics["conversions"].to_f
      end
    end

    def blank_month
      { cost_cents: 0, impressions: 0, clicks: 0, conversions: 0.0 }
    end

    # The currency comes back on every row; an account with no spend in the
    # window returns none, so fall back to asking for it directly rather than
    # storing nil and rendering a client's spend without a currency.
    def account_currency(customer_id, rows)
      from_rows = rows.filter_map { |row| row.dig("customer", "currencyCode").presence }.first
      return from_rows if from_rows

      client.describe(customer_id)&.dig(:currency_code)
    end
  end
end
