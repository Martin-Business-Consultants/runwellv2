# A person approving an app to act as them: signed in in the browser, they see which app and
# what it may do (everything their role allows), and say yes or no. Yes redirects back with a
# single-use code bound to the redirect URI and the PKCE challenge.
class Oauth::AuthorizationsController < ApplicationController
  allow_staff
  agent_exempt :show, :create, reason: "a person approving an app in the browser"
  before_action :set_request

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
    def set_request
      @client = OauthClient.find_by(uid: params[:client_id])
      @redirect_uri = params[:redirect_uri].to_s
      # Never redirect to an address the client didn't register: show the problem here instead.
      return render(:invalid, status: :bad_request) unless @client&.redirect_uri?(@redirect_uri)
      return redirect_back_with(error: "unsupported_response_type") unless params[:response_type] == "code"

      redirect_back_with(error: "invalid_request", error_description: "PKCE (S256) is required") unless params[:code_challenge].present? && params[:code_challenge_method] == "S256"
    end

    def redirect_back_with(**answer)
      uri = URI(@redirect_uri)
      uri.query = [ uri.query.presence, answer.merge(state: params[:state]).compact.to_query ].compact.join("&")
      redirect_to uri.to_s, allow_other_host: true
    end
end
