# The financial report for a period.
module Reporting
  class ReportsController < ApplicationController
    require_permission :view_financials
    agent_tool :show_financial_report, on: :show, title: "Show the financial report",
      description: "Billed and collected in the period and by month, receivables by age, revenue by client, recurring revenue and whether QuickBooks bills it, approved work not yet invoiced, and QuickBooks’ profit and loss. All from QuickBooks.",
      params: { period: Period::NAMES }

    def show
      @period = Period.new(params[:period])
      @financials = Financials.new(@period) if Reporting.source_ready?
    end
  end
end
