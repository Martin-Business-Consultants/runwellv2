# A new report URL for a check, when the old one was shared where it shouldn't have been.
module Qa
  class TokensController < ApplicationController
    allow_staff
    agent_tool :reset_qa_report_url, on: :create, title: "Give a QA check a new report URL",
      description: "The old URL stops working at once; the site reporting to it needs the new one."

    before_action :set_check, :require_check_editor

    def create
      @check.regenerate_report_token
      redirect_back fallback_location: qa_check_path(@check), notice: "New report URL made. Update the site that reports to it."
    end
  end
end
