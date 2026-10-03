# Google, Microsoft or GitHub answering (config/initializers/omniauth.rb). Signed in already, it
# connects that account to you (Settings > Your account); signed out, it signs in whoever
# connected it, or the person whose address the provider vouches for (Identity.user_for), then
# two-factor sign-in if they have it. Nobody joins this way.
class Sessions::OmniauthsController < ApplicationController
  allow_unauthenticated_access

  def create
    auth = request.env["omniauth.auth"]
    return failure unless auth

    resume_session ? connect(auth) : sign_in(auth)
  end

  def failure
    redirect_to (resume_session ? settings_account_path : new_session_path), alert: "Signing in with #{SignInProvider.name_for(params[:strategy] || request.env["omniauth.error.strategy"]&.name)} didn’t work. Try again, or use your password."
  end

  private
    def sign_in(auth)
      if (user = Identity.user_for(auth))
        sign_in_after_first_step user, method: auth.provider
      else
        redirect_to new_session_path, alert: "No one here signs in with that #{SignInProvider.name_for(auth.provider)} account. Sign in another way and connect it in Settings › Your account, or ask an owner for an invitation."
      end
    end

    def connect(auth)
      identity = Identity.find_or_initialize_by(provider: auth.provider, uid: auth.uid.to_s)
      if identity.persisted? && identity.user != Current.user
        redirect_to settings_account_path, alert: "That #{identity.provider_name} account is connected to someone else."
      else
        identity.update!(user: Current.user, email: auth.info.email, last_used_at: Time.current)
        Current.user.record_event!("user.identity_connected", payload: { provider: auth.provider })
        redirect_to settings_account_path, notice: "#{identity.provider_name} connected. You can sign in with it now."
      end
    end
end
