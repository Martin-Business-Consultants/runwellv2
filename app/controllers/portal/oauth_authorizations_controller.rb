# A client's contact approving their own AI app: signed in to the portal (by emailed link, which
# brings them back here), they see the app and what it may do as them, and say yes or no. The
# token it gets reaches their portal only (Portal::McpController).
class Portal::OauthAuthorizationsController < Portal::BaseController
  agent_exempt :show, :create, reason: "a client approving an app in the browser"
  include OauthAuthorizing

  layout "public"

  def show
  end

  def create
    return redirect_back_with(error: "access_denied") unless params[:approve] == "1"

    grant = OauthGrant.issue!(client: @client, contact: current_contact, redirect_uri: @redirect_uri, code_challenge: params[:code_challenge],
      read_only: params[:read_only] == "1")
    redirect_back_with(code: grant.code)
  end
end
