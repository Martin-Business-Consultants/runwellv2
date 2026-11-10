class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  allow_staff only: :destroy
  skip_before_action :require_two_factor_setup, only: :destroy
  agent_exempt :destroy, reason: "signing a browser out; revoke a token in Settings > Connected apps"

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  bot_checked fallback: -> { new_session_path }

  layout "public"

  # A new install has no one to sign in yet: its first visitor sets it up as the owner.
  # Marked as the sign-in page, so a frame or stream that lands here (a session that ran out) sends
  # the whole page to sign in (the connection controller).
  def new
    response.set_header("X-Runwell-Sign-In", "1")
    redirect_to new_signup_path unless User.exists?
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password))) && user.active? && !user.agent? && user.staff?
      sign_in_after_first_step user
    else
      record_failed_sign_in(User.people.find_by(email_address: params[:email_address].to_s.strip.downcase), "password")
      redirect_to new_session_path(email_address: params[:email_address]), alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
