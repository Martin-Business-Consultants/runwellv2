# Settings > Your account: disconnect a Google, Microsoft or GitHub account you sign in with.
class Settings::IdentitiesController < ApplicationController
  allow_staff
  agent_exempt :destroy, reason: "how a person signs in is changed by them in the browser"

  def destroy
    identity = Current.user.identities.find(params[:id])
    identity.destroy!
    Current.user.record_event!("user.identity_disconnected", payload: { provider: identity.provider })
    redirect_to settings_account_path, notice: "#{identity.provider_name} disconnected."
  end
end
