# Inviting someone onto the team (Users): an emailed link that works once and expires.
class Users::InvitationsController < ApplicationController
  require_permission :manage_people
  agent_tool :invite_person, on: :create, title: "Invite someone to the team",
    params: { invitation: { email_address: "string!", role: User::ROLES } }
  agent_tool :resend_invitation, on: :update, title: "Resend an invitation"
  agent_tool :withdraw_invitation, on: :destroy, title: "Withdraw an invitation"

  def new
    @invitation = Invitation.new(role: "member")
    @invitations = Invitation.pending.ordered.includes(:invited_by)
  end

  def create
    invitation = Invitation.new(params.expect(invitation: %i[email_address role]).merge(invited_by: current_user))
    if invitation.save
      invitation.deliver
      redirect_to new_user_invitation_path, notice: "Invitation sent to #{invitation.email_address}."
    else
      redirect_to new_user_invitation_path, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def update
    invitation = Invitation.pending.find(params[:id])
    invitation.resend!
    redirect_back_or_to new_user_invitation_path, notice: "Sent a new link to #{invitation.email_address}."
  end

  def destroy
    invitation = Invitation.pending.find(params[:id])
    invitation.destroy!
    redirect_back_or_to new_user_invitation_path, notice: "Invitation to #{invitation.email_address} withdrawn."
  end
end
