# Settings > Connected apps, for everyone: the AI apps and tokens acting as you. Make a personal
# token for the CLI or a script (shown once), see what each app did (AgentCall), pause one, and
# disconnect any. An owner also sees every connection in the install, clients' included, and can
# pause or disconnect them. Managing access stays with a person in the browser: agents can't
# mint, pause or revoke tokens.
class Settings::ConnectedAppsController < ApplicationController
  allow_staff
  agent_exempt :index, :create, :destroy, reason: "access tokens are managed by a person in the browser"

  def index
    load_tokens
  end

  def create
    attrs = params.expect(access_token: %i[name read_only])
    @new_token = AccessToken.issue!(user: current_user, name: attrs[:name].presence || "Personal token", read_only: attrs[:read_only] == "1")
    load_tokens
    render :index, status: :created
  end

  def destroy
    token = manageable_tokens.find(params[:id])
    token.revoke!
    redirect_to settings_connected_apps_path, notice: "#{token.name} disconnected."
  end

  private
    def load_tokens
      @tokens = current_user.access_tokens.live.ordered.includes(:oauth_client)
      @everyone = AccessToken.live.where.not(id: @tokens).ordered.includes(:user, :contact, :oauth_client) if can?(:manage_people)
    end

    # Your own, or, for an owner, anyone's.
    def manageable_tokens = can?(:manage_people) ? AccessToken.live : current_user.access_tokens.live
end
