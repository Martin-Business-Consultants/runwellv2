class BriefingsController < ApplicationController
  allow_staff
  agent_tool :briefing, on: :show, title: "What needs a person now",
    description: "Start here. The person's own open work by when it's due (overdue, due today, this week, in progress with no date that close), then what's waiting on them: work in review they lead, blocked work they're on, unread mentions, and anything plugins add. Each item names the tool that shows it."

  def show
    # The briefing tool lists 25 of each; home shows a few, with the way to the rest.
    @briefing = Briefing.new(current_user, limit: request.format.json? ? 25 : helpers.briefing_shown)
    @release = Release.latest if current_user.can?(:manage_settings) && Upgrade.current.nil?
  end
end
