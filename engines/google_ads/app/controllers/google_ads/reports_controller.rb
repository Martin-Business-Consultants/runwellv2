# The advertising report for an engagement's ad account, as staff see it (the same report
# the client sees in their portal).
module GoogleAds
  class ReportsController < ApplicationController
    allow_staff
    agent_tool :show_ads_report, on: :show, title: "Show an engagement’s advertising report",
      description: "Spend, leads, cost per lead, clicks, impressions, rates and impression share for a month, against the same stretch of the month before, with daily and monthly series.",
      params: { month: "string" }

    def show
      @engagement = ::Engagement.find_by!(ref: params[:engagement_ref].to_s.upcase)
      @link = @engagement.google_ads_link or raise ActiveRecord::RecordNotFound
      @report = Report.new(@link.customer_id, month: Report.parse_month(params[:month]))
    end
  end
end
