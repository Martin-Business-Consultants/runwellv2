class BriefingsController < ApplicationController
  allow_staff
  agent_tool :briefing, on: :show, title: "What needs a person now",
    description: "Start here. The home page: questions for you, requests to triage, agreements awaiting the client, drafts ready to send, overdue and due commitments, blocked and overdue work, and anything plugins add. Each item names the tool that shows it."

  def show
    @sections = Briefing.new(current_user).sections
    @setup = Setup.new(current_user)
    @release = Release.latest if current_user.can?(:manage_settings) && Upgrade.current.nil?
  end
end
