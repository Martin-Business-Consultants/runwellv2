class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  allow_staff only: :destroy
  agent_exempt :destroy, reason: "signing a browser out; revoke a token in Settings > Connected apps"

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password))) && user.active? && !user.agent?
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path(email_address: params[:email_address]), alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
