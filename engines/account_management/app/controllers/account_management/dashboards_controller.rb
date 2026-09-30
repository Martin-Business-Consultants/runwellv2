# Accounts at a glance: each lead's scorecard against the playbook, the meetings whose agenda or
# recap is due, the accounts that need attention and the clients nobody leads.
module AccountManagement
  class DashboardsController < ApplicationController
    allow_staff
    agent_tool :show_accounts, on: :show, title: "Show account management: leads, scorecards and what’s due",
      description: "Each lead's scorecard for the last 30 days (agendas, recaps, commitments, weekly updates against the playbook's targets), meetings whose agenda or recap is due, accounts needing attention, and clients without a lead."

    def show
      leaders = ::User.where(id: Lead.select(:user_id)).or(::User.where(id: Meeting.where(starts_at: 30.days.ago..).select(:owner_id)))
      leaders = leaders.where(id: Current.user.id) unless Current.user.can?(:view_scorecards)
      @scorecards = leaders.active.ordered.map { Scorecard.new(it) }
      @agendas_due = Meeting.needing_agenda.where(starts_at: ..7.days.from_now).includes(:client, :owner)
      @recaps_due = Meeting.needing_recap.where(starts_at: 30.days.ago..).includes(:client, :owner)
      @accesses = Access.includes(:client).ordered.reject(&:in_order?)
      @unled = ::Client.active.where.not(id: Lead.select(:client_id)).ordered
    end
  end
end
