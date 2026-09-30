module AccountManagement
  class LeadsController < ApplicationController
    allow_staff
    before_action :require_account_manager
    agent_tool :set_account_lead, on: :update, title: "Set who leads a client",
      description: "client_id from the path. user_id: the person who answers for the client (its meetings, commitments, accesses and weekly update); blank removes the lead.",
      params: { user_id: "integer" }

    def update
      client = ::Client.find(params[:client_id])
      if (user = ::User.active.people.find_by(id: params[:user_id]))
        (client.account_lead || client.build_account_lead).update!(user: user)
        client.record_event!("account.lead_set", payload: { lead: user.display_name })
        redirect_back fallback_location: client_path(client), notice: "#{user.display_name} leads #{client.name}."
      else
        client.account_lead&.destroy!
        redirect_back fallback_location: client_path(client), notice: "Nobody leads #{client.name} now."
      end
    end
  end
end
