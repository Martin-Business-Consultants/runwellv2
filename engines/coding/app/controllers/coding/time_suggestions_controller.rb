# Time worth logging, suggested from your commits on work, and logging it (with Time
# tracking on). Nothing is logged until someone says so.
module Coding
  class TimeSuggestionsController < ApplicationController
    allow_staff
    agent_tool :show_time_suggestions, on: :index, title: "Show time suggested from your commits"
    agent_tool :log_suggested_time, on: :create, title: "Log suggested time",
      description: "suggestion: an id from show_time_suggestions, like 58-2026-09-25. duration overrides the suggestion (1:30, 90 or 1.5h). Needs Time tracking switched on.",
      params: { suggestion: "string!", duration: "string" }

    def index
      @suggestions = TimeSuggestion.for(Current.user)
      @time_tracking = time_tracking?
    end

    def create
      return redirect_back(fallback_location: coding_time_suggestions_path, alert: "Switch on Time tracking in Settings > Plugins to log time.") unless time_tracking?

      suggestion = TimeSuggestion.for(Current.user).find { it.id == params[:suggestion] } or
        return redirect_back(fallback_location: coding_time_suggestions_path, alert: "That suggestion has already been logged or dismissed.")
      minutes = params[:duration].present? ? TimeTracking::Entry.minutes_from(params[:duration]) : suggestion.minutes
      entry = TimeTracking::Entry.new(user: Current.user, trackable: suggestion.todo, minutes: minutes, worked_on: suggestion.date, note: suggestion.note)
      if entry.save
        suggestion.settle!(:logged_at)
        redirect_back fallback_location: coding_time_suggestions_path, notice: "#{helpers.code_duration(entry.minutes)} logged on “#{suggestion.todo.title}”."
      else
        redirect_back fallback_location: coding_time_suggestions_path, alert: "Enter a duration like 1:30, 90 or 1.5h."
      end
    end

    private
      def time_tracking? = Runwell::Plugins.enabled?(:time_tracking) && defined?(TimeTracking::Entry)
  end
end
