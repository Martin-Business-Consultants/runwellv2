# The checks an OAuth authorization request must pass before anyone is asked to approve it,
# shared by staff consent (Oauth::AuthorizationsController) and a client's (Portal::
# OauthAuthorizationsController): a registered client, its own redirect URI, the code flow,
# and PKCE (S256). Answers go back to that redirect URI with the state.
module OauthAuthorizing
  extend ActiveSupport::Concern

  included do
    before_action :set_authorization_request
  end

  # Whether a request is for a client's portal: it names the portal's MCP endpoint as its
  # resource (RFC 8707), or asks for the portal scope.
  def self.for_portal?(params) = params[:resource].to_s.include?("/portal/mcp") || params[:scope].to_s.split.include?("runwell:portal")

  private
    def set_authorization_request
      @client = OauthClient.find_by(uid: params[:client_id])
      @redirect_uri = params[:redirect_uri].to_s
      # Never redirect to an address the client didn't register: show the problem here instead.
      return render("oauth/authorizations/invalid", status: :bad_request) unless @client&.redirect_uri?(@redirect_uri)
      return redirect_back_with(error: "unsupported_response_type") unless params[:response_type] == "code"

      redirect_back_with(error: "invalid_request", error_description: "PKCE (S256) is required") unless params[:code_challenge].present? && params[:code_challenge_method] == "S256"
    end

    def redirect_back_with(**answer)
      uri = URI(@redirect_uri)
      uri.query = [ uri.query.presence, answer.merge(state: params[:state]).compact.to_query ].compact.join("&")
      redirect_to uri.to_s, allow_other_host: true
    end
end
