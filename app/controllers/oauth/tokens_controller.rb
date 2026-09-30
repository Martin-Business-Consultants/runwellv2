# The token endpoint: a code (with its PKCE verifier) or a refresh token for an access token.
class Oauth::TokensController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  rate_limit to: 60, within: 1.minute, only: :create

  def create
    client = OauthClient.find_by(uid: params[:client_id])
    return oauth_error("invalid_client") unless client

    token =
      case params[:grant_type]
      when "authorization_code"
        OauthGrant.redeem!(code: params[:code].to_s, client: client, redirect_uri: params[:redirect_uri].to_s, code_verifier: params[:code_verifier].to_s)
      when "refresh_token"
        old = AccessToken.find_by(refresh_token_digest: AccessToken.digest(params[:refresh_token].to_s), oauth_client: client)
        AccessToken.refresh!(params[:refresh_token].to_s) if old
      else
        return oauth_error("unsupported_grant_type")
      end
    return oauth_error("invalid_grant") unless token

    response.headers["Cache-Control"] = "no-store"
    render json: { access_token: token.plaintext, token_type: "Bearer", expires_in: AccessToken::OAUTH_LIFETIME.to_i,
      refresh_token: token.refresh_plaintext, scope: token.scope }
  end

  private
    def oauth_error(code) = render(json: { error: code }, status: :bad_request)
end
