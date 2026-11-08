# Settings > Updates on an install KamalCloud runs (Upgrade::Hoster): the token that lets an update
# move the app's image and deploy it there with no downtime. Set in the browser only: it's a key to
# another service, which agents never handle.
class Settings::Updates::HosterTokensController < Settings::BaseController
  browser_only :update, reason: "a KamalCloud token, a key to another service, is pasted in the browser"
  browser_only :destroy, reason: "removing a key to another service is done in the browser"

  def update
    token = params.dig(:setting, :hoster_token).to_s.strip
    return redirect_to(settings_updates_path, alert: "Paste a token from KamalCloud first.") if token.blank?

    Setting.current.update!(hoster_token: token)
    redirect_to settings_updates_path, notice: "Saved. Updates now deploy on KamalCloud with no downtime."
  end

  def destroy
    Setting.current.update!(hoster_token: nil)
    redirect_to settings_updates_path, notice: "Removed. Updates restart this install in place again."
  end
end
