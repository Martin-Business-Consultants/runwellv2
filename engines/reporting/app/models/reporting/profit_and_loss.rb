module Reporting
  # QuickBooks' own profit and loss for the period, accrual basis: the one report whose costs
  # Runwell never sees. Asked of QuickBooks and kept for an hour, since the books move slowly
  # and each ask is a call to Intuit.
  class ProfitAndLoss
    GROUPS = { "Income" => :income, "COGS" => :cost_of_sales, "GrossProfit" => :gross_profit, "Expenses" => :expenses,
      "NetOperatingIncome" => :operating_income, "OtherIncome" => :other_income, "OtherExpenses" => :other_expenses, "NetIncome" => :net_income }.freeze

    attr_reader :totals, :income_lines, :expense_lines, :error

    def self.for(period)
      connection = Quickbooks::Connection.current
      return new(error: "QuickBooks isn’t connected.") unless connection&.connected?

      Rails.cache.fetch([ "reporting/pnl", connection.realm_id, period.from, period.to ], expires_in: 1.hour) do
        new(report: Quickbooks::Api.new(connection).report("ProfitAndLoss", start_date: period.from.iso8601, end_date: period.to.iso8601, accounting_method: "Accrual"))
      end
    rescue Quickbooks::Api::Error => e
      new(error: e.message)
    end

    def initialize(report: nil, error: nil)
      @error = error
      @totals = {}
      @income_lines = []
      @expense_lines = []
      Array(report&.dig("Rows", "Row")).each { read(it) }
    end

    def available? = error.nil?
    def [](key) = totals[key]
    def margin = totals[:income].to_i.positive? && totals[:net_income] ? (totals[:net_income] * 100.0 / totals[:income]).round : nil

    private
      def read(section)
        key = GROUPS[section["group"]] or return
        totals[key] = cents(section.dig("Summary", "ColData", 1, "value"))
        lines = Array(section.dig("Rows", "Row")).filter_map { line(it) }.sort_by { -it[:cents] }
        @income_lines = lines if key == :income
        @expense_lines = lines if key == :expenses
      end

      def line(row)
        if row["type"] == "Section"
          { name: row.dig("Header", "ColData", 0, "value"), cents: cents(row.dig("Summary", "ColData", 1, "value")) }
        else
          { name: row.dig("ColData", 0, "value"), cents: cents(row.dig("ColData", 1, "value")) }
        end
      end

      def cents(value) = (value.to_f * 100).round
  end
end
