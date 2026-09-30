# "Check the page now": the nightly page check, on demand.
module Qa
  class FetchesController < ApplicationController
    allow_staff
    agent_tool :check_qa_page, on: :create, title: "Fetch a QA check's page now",
      description: "Loads the check's URL and answers its includes / excludes expectations (a phone number, a price, a number that must never show)."

    before_action :set_check

    def create
      return redirect_back(fallback_location: qa_check_path(@check), alert: "Give the check a URL and at least one value that must appear, or never appear, on it.") unless @check.fetchable?

      run = PageFetch.new(@check).call(user: Current.user, source: Current.source == "agent" ? "agent" : "page")
      redirect_back fallback_location: qa_check_path(@check), notice: "#{run.passed? ? "Passed" : "Failed"}: #{run.summary}."
    end
  end
end
