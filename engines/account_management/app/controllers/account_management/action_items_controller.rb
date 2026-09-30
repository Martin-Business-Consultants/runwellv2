# An action item from a meeting: a core commitment with an owner (ours or theirs) and a date,
# kept with the meeting so its recap lists it.
module AccountManagement
  class ActionItemsController < ApplicationController
    allow_staff
    agent_tool :add_meeting_action_item, on: :create, title: "Add an action item to a meeting",
      description: "Becomes a commitment on the client (and engagement): owner is us, user:<id>, client or contact:<id>. Listed in the recap.",
      params: { action_item: { description: "string!", owner: "string!", due_on: "date!" } }

    def create
      meeting = Meeting.find(params[:meeting_id])
      return redirect_to(account_management_meeting_path(meeting), alert: "The recap is out; add it as a commitment on the #{helpers.term(:client).downcase} instead.") if meeting.recap_sent?

      attributes = params.expect(action_item: %i[description owner due_on])
      commitment = meeting.add_action_item!(**attributes.to_h.symbolize_keys)
      redirect_to account_management_meeting_path(meeting), notice: "Action item added: #{commitment.owner_name}, by #{l commitment.due_on, format: :short}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to account_management_meeting_path(meeting), alert: e.record.errors.full_messages.to_sentence
    end
  end
end
