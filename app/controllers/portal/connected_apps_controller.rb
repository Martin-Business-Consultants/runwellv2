# The portal's Connected apps: a client's contact connects their own AI (Muse, Claude, ChatGPT…)
# to see their work and send requests. A personal token (shown once), or OAuth from the app; see
# what each did, and disconnect any. Only a person in the browser manages these.
class Portal::ConnectedAppsController < Portal::BaseController
  agent_exempt :index, :create, :destroy, reason: "access tokens are managed by a person in the browser"

  def index
    load_tokens
  end

  def create
    attrs = params.expect(access_token: %i[name read_only])
    @new_token = AccessToken.issue!(contact: current_contact, name: attrs[:name].presence || "Personal token", read_only: attrs[:read_only] == "1")
    load_tokens
    render :index, status: :created
  end

  def destroy
    token = current_contact.access_tokens.live.find(params[:id])
    token.revoke!
    redirect_to portal_connected_apps_path, notice: "#{token.name} disconnected."
  end

  private
    def load_tokens = @tokens = current_contact.access_tokens.live.ordered.includes(:oauth_client)
end
