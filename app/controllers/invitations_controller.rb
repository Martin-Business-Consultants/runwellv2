# Accepting an invitation: the emailed link shows a form for a name and password, and
# accepting signs the new person in.
class InvitationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to new_session_path, alert: "Try again later." }
  before_action :set_invitation

  layout "public"

  def show
    @user = User.new(email_address: @invitation.email_address)
  end

  def update
    user = @invitation.accept!(**params.expect(user: %i[name password]).to_h.symbolize_keys)
    terminate_session if authenticated?
    start_new_session_for user
    redirect_to root_path, notice: "Welcome to Runwell, #{user.display_name}."
  rescue ActiveRecord::RecordInvalid => error
    @user = error.record.is_a?(User) ? error.record : User.new(email_address: @invitation.email_address)
    render :show, status: :unprocessable_entity
  end

  private
    def set_invitation
      @invitation = Invitation.pending.find_by_token(params[:token])
      redirect_to new_session_path, alert: "That invitation has expired or was already used. Ask for a new one." unless @invitation
    end
end
