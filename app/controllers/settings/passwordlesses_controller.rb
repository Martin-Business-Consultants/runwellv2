# Settings > Your account: sign in with an emailed link as well as the password.
class Settings::PasswordlessesController < ApplicationController
  allow_staff
  agent_exempt :update, reason: "how a person signs in is changed by them in the browser"

  def update
    on = params.dig(:user, :passwordless) == "1"
    Current.user.update!(passwordless: on)
    Current.user.record_event!(on ? "user.link_sign_in_on" : "user.link_sign_in_off")
    redirect_to settings_account_path, notice: on ? "You can sign in with an emailed link." : "Sign-in by link is off."
  end
end
