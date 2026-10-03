# Signing in, second step: the password was right (SessionsController), and now a code from the
# authenticator app or a recovery code. The half-signed-in state lives in the encrypted session
# cookie for five minutes and five tries, then it's back to the password.
class Sessions::TwoFactorsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  EXPIRES_IN = 5.minutes
  TRIES = 5

  layout "public"

  before_action :require_pending_user

  def new
  end

  def create
    if @user.verify_second_factor(params[:code])
      session.delete(:two_factor)
      start_new_session_for @user
      notice = ("#{@user.recovery_codes_left} recovery codes left. Make new ones in Settings › Your account." if @user.recovery_codes_left < 3)
      redirect_to after_authentication_url, notice: notice
    else
      wrong_code
    end
  end

  private
    def require_pending_user
      pending = session[:two_factor]
      @user = User.active.find_by(id: pending["user_id"]) if pending && Time.at(pending["at"].to_i) > EXPIRES_IN.ago
      return if @user&.two_factor?

      session.delete(:two_factor)
      redirect_to new_session_path, alert: ("Sign in again: that took too long." if pending)
    end

    def wrong_code
      tries = session[:two_factor]["tries"].to_i + 1
      if tries >= TRIES
        session.delete(:two_factor)
        redirect_to new_session_path, alert: "Too many wrong codes. Sign in again."
      else
        session[:two_factor] = session[:two_factor].merge("tries" => tries)
        redirect_to new_session_two_factor_path, alert: "That code didn’t work. Try the newest one from your app, or a recovery code."
      end
    end
end
