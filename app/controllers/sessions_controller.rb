class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  allow_staff only: :destroy
  skip_before_action :require_two_factor_setup, only: :destroy
  agent_exempt :destroy, reason: "signing a browser out; revoke a token in Settings > Connected apps"

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  # A new install has no one to sign in yet: its first visitor sets it up as the owner.
  def new
    redirect_to new_signup_path unless User.exists?
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password))) && user.active? && !user.agent?
      sign_in_after_first_step user
    else
      redirect_to new_session_path(email_address: params[:email_address]), alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
