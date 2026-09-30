module Coding
  class TimeDismissalsController < ApplicationController
    allow_staff
    agent_tool :dismiss_time_suggestion, on: :create, title: "Dismiss a time suggestion", params: { suggestion: "string!" }

    def create
      suggestion = TimeSuggestion.for(Current.user).find { it.id == params[:suggestion] }
      suggestion&.settle!(:dismissed_at)
      redirect_back fallback_location: coding_time_suggestions_path, notice: "Dismissed."
    end
  end
end
