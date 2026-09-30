class Settings::InvitationsController < ApplicationController
  require_permission :manage_people
  agent_tool :invite_person, on: :create, title: "Invite someone to the team",
    params: { invitation: { email_address: "string!", role: User::ROLES } }
  agent_tool :resend_invitation, on: :update, title: "Resend an invitation"
  agent_tool :withdraw_invitation, on: :destroy, title: "Withdraw an invitation"

  def create
    invitation = Invitation.new(params.expect(invitation: %i[email_address role]).merge(invited_by: current_user))
    if invitation.save
      invitation.deliver
      redirect_to settings_people_path, notice: "Invitation sent to #{invitation.email_address}."
    else
      redirect_to settings_people_path, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def update
    invitation = Invitation.pending.find(params[:id])
    invitation.resend!
    redirect_to settings_people_path, notice: "Sent a new link to #{invitation.email_address}."
  end

  def destroy
    invitation = Invitation.pending.find(params[:id])
    invitation.destroy!
    redirect_to settings_people_path, notice: "Invitation to #{invitation.email_address} withdrawn."
  end
end
