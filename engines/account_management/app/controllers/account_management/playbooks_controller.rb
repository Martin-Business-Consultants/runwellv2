# The playbook: what the person running client relationships owns and the numbers they're held to.
module AccountManagement
  class PlaybooksController < ApplicationController
    allow_staff
    agent_tool :show_account_playbook, on: :show, title: "Show the account management playbook",
      description: "What a lead owns (client relationships, briefs before work, QA before anything ships, coordination, the weekly update), the targets the scorecard holds them to, and the first 90 days."

    def show
    end
  end
end
