# A person approving an app to act as them: signed in in the browser, they see which app and
# what it may do (everything their role allows), and say yes or no. Yes redirects back with a
# single-use code bound to the redirect URI and the PKCE challenge. A request for a client's
# portal goes to the portal's own consent, where a contact signs in by emailed link.
class Oauth::AuthorizationsController < ApplicationController
  prepend_before_action :hand_clients_to_portal, only: :show
  allow_staff
  agent_exempt :show, :create, reason: "a person approving an app in the browser"
  include OauthAuthorizing

  layout "public"

  def show
  end

  def create
    return redirect_back_with(error: "access_denied") unless params[:approve] == "1"

    grant = OauthGrant.issue!(client: @client, user: current_user, redirect_uri: @redirect_uri, code_challenge: params[:code_challenge],
      read_only: params[:read_only] == "1")
    redirect_back_with(code: grant.code)
  end

  private
    def hand_clients_to_portal
      redirect_to portal_oauth_authorization_path(request.query_parameters) if OauthAuthorizing.for_portal?(params)
    end
end
