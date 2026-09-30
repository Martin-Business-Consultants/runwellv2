module Reporting
  # The money, read from the QuickBooks plugin's mirror. Two numbers that are not the same:
  # billed (what went out on invoices in the period: what the work was worth when done) and
  # collected (what arrived in the period, whichever month it was billed). Integer cents.
  class Financials
    AGING = [ [ "Not due", ..0 ], [ "1–30 days", 1..30 ], [ "31–60 days", 31..60 ], [ "61–90 days", 61..90 ], [ "Over 90 days", 91.. ] ].freeze
    # A period's worth of a recurring amount, as a month.
    MONTHLY = { "weekly" => 52 / 12r, "monthly" => 1r, "quarterly" => 1 / 3r }.freeze

    def initialize(period)
      @period = period
    end

    attr_reader :period

    def invoices = Quickbooks::Invoice.live.where(txn_date: period.range)
    def payments = Quickbooks::Payment.joins(:invoice).merge(Quickbooks::Invoice.live).where(paid_on: period.range)

    def billed_cents = invoices.sum(:total_cents)
    def collected_cents = payments.sum(:amount_cents)
    def outstanding_cents = Quickbooks::Invoice.open.sum(:balance_cents)
    def overdue_cents = Quickbooks::Invoice.overdue.sum(:balance_cents)

    # Billed and collected for each of the last twelve months, zero-filled: a month nobody
    # paid in is worth drawing, and leaving it out slides the chart.
    def by_month
      months = (0..11).map { Date.current.beginning_of_month << it }.reverse
      span = months.first..Date.current.end_of_month
      billed = Quickbooks::Invoice.live.where(txn_date: span).group("strftime('%Y-%m', txn_date)").sum(:total_cents)
      collected = Quickbooks::Payment.joins(:invoice).merge(Quickbooks::Invoice.live).where(paid_on: span).group("strftime('%Y-%m', paid_on)").sum(:amount_cents)
      months.map do |month|
        key = month.strftime("%Y-%m")
        { label: month.strftime("%b"), full_label: month.strftime("%B %Y"), billed: billed[key].to_i, collected: collected[key].to_i, current: month == Date.current.beginning_of_month }
      end
    end

    # What clients owe now, by how late it is.
    def aging
      open = Quickbooks::Invoice.open.to_a
      AGING.map do |label, days|
        matching = open.select { days.cover?(it.due_on ? (Date.current - it.due_on).to_i : 0) }
        { label: label, cents: matching.sum(&:balance_cents), count: matching.size }
      end
    end

    # Clients by what was billed in the period, with what they paid and still owe.
    def by_client
      billed = invoices.group(:client_id).sum(:total_cents)
      collected = payments.group("quickbooks_invoices.client_id").sum(:amount_cents)
      owed = Quickbooks::Invoice.open.group(:client_id).sum(:balance_cents)
      ids = (billed.keys | collected.keys | owed.keys)
      ::Client.where(id: ids).map { |client| { client: client, billed: billed[client.id].to_i, collected: collected[client.id].to_i, owed: owed[client.id].to_i } }
        .sort_by { -it[:billed] }
    end

    # Fixed-price work the client approved that hasn't all been invoiced: money earned or
    # promised and not yet asked for.
    def unbilled
      invoiced = Quickbooks::Invoice.billed.where.not(engagement_id: nil).group(:engagement_id).sum(:total_cents)
      ::Engagement.where(shape: "fixed").includes(:client, agreement_versions: [ :approval, :scope_items ]).select(&:approved?)
        .map { |engagement| { engagement: engagement, agreed: engagement.agreed_amount_cents, invoiced: invoiced[engagement.id].to_i } }
        .select { it[:agreed] > it[:invoiced] }.sort_by { it[:invoiced] - it[:agreed] }
    end

    # Every open service, its agreed amount as a month, and whether QuickBooks bills it as
    # agreed. Recurring revenue QuickBooks doesn't bill is revenue quietly going unbilled.
    def recurring
      links = Quickbooks::RecurringLink.all.index_by(&:engagement_id)
      ::Engagement.open.where(shape: "recurring").includes(:client, agreement_versions: [ :approval, :scope_items ]).select(&:approved?).map do |engagement|
        version = engagement.current_version
        link = links[engagement.id]
        monthly = (version.amount_cents * MONTHLY.fetch(version.cadence.to_s, 1r)).round
        state = if link.nil? then "not billed" elsif !link.in_sync? then "out of step" else "billed" end
        { engagement: engagement, amount: version.amount_cents, cadence: version.cadence, monthly: monthly, link: link, state: state }
      end.sort_by { -it[:monthly] }
    end

    def monthly_recurring_cents = recurring.sum { it[:monthly] }
    def monthly_recurring_billed_cents = recurring.select { it[:state] == "billed" }.sum { it[:monthly] }

    def profit_and_loss = ProfitAndLoss.for(period)
  end
end
