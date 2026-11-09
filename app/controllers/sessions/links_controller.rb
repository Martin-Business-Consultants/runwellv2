# Signing in by emailed link, for people who switched it on (Settings > Your account); someone on
# the team who hasn't is emailed how to. Asking always answers the same, so nobody learns who has
# an account. The link opens a page with a
# button rather than signing in on the GET, since mail scanners open links before people do; it
# works once, for 15 minutes, and two-factor sign-in still follows.
class Sessions::LinksController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_session_link_path, alert: "Try again later." }
  bot_checked fallback: -> { new_session_link_path }

  layout "public"

  def new
  end

  def create
    user = User.people.active.find_by(email_address: params[:email_address].to_s.strip.downcase)
    # A link for those who switched it on; for anyone else on the team, how to switch it on.
    if user&.passwordless?
      SessionMailer.with(user: user).link.deliver_later
    elsif user
      SessionMailer.with(user: user).link_off.deliver_later
    end
    redirect_to new_session_path, notice: "If that address can sign in by link, one is on its way. It works for 15 minutes."
  end

  def show
    redirect_to new_session_path, alert: "That link has expired or been used. Ask for a new one." unless link_user
  end

  def update
    if (user = link_user)
      user.update!(link_signed_in_at: Time.current)
      sign_in_after_first_step user, method: "link"
    else
      redirect_to new_session_path, alert: "That link has expired or been used. Ask for a new one."
    end
  end

  private
    def link_user
      @link_user ||= User.find_by_token_for(:link_sign_in, params[:token])&.then { it if it.active? && it.staff? && it.passwordless? }
    end
end
