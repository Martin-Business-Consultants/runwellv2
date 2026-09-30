# Settings > Connected apps, for everyone: the AI apps and tokens acting as you. Make a personal
# token for the CLI or a script (shown once), see what each app last did, and disconnect any.
# Managing access stays with a person in the browser: agents can't mint or revoke tokens.
class Settings::ConnectedAppsController < ApplicationController
  allow_staff
  agent_exempt :index, :create, :destroy, reason: "access tokens are managed by a person in the browser"

  def index
    @tokens = current_user.access_tokens.live.ordered.includes(:oauth_client)
  end

  def create
    attrs = params.expect(access_token: %i[name read_only])
    @new_token = AccessToken.issue!(user: current_user, name: attrs[:name].presence || "Personal token", read_only: attrs[:read_only] == "1")
    @tokens = current_user.access_tokens.live.ordered.includes(:oauth_client)
    render :index, status: :created
  end

  def destroy
    token = current_user.access_tokens.find(params[:id])
    token.revoke!
    redirect_to settings_connected_apps_path, notice: "#{token.name} disconnected."
  end
end
