# QA at a glance: the numbers it's held to, and every check by client with its state.
module Qa
  class DashboardsController < ApplicationController
    allow_staff
    agent_tool :show_qa, on: :show, title: "Show QA: every check's state and the numbers",
      description: "Each client's checks (failing, due for a test, passing) with owners, facts expiring soon, and the last 30 days: tests, pass rate, issues found, escapes (found live), time to fix, root causes.",
      params: { state: %w[all failing due passing], client_id: "integer" }

    def show
      @state = params[:state].presence_in(%w[all] + Check::STATES) || "all"
      @stats = Stats.new
      scope = Check.active.includes(:client, :owner, :engagement, :expectations, :issues).joins(:client).order("clients.name", :name)
      scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
      @checks = scope.to_a
      @checks = @checks.select { it.state == @state } unless @state == "all"
      paginate_checks if request.format.html?
      @expiring = Expectation.joins(:check).merge(Check.active).where(expires_on: ..14.days.from_now.to_date).includes(check: :client).order(:expires_on)
    end

    private
      PER_PAGE = 10

      # Ten a page, with numbered pages. State is worked out per check, so this pages the list
      # itself rather than the query.
      def paginate_checks
        @total = @checks.size
        @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max
        @page_number = params[:page].to_i.clamp(1, @pages)
        @checks = @checks.slice((@page_number - 1) * PER_PAGE, PER_PAGE) || []
      end
  end
end
