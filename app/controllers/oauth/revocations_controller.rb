# Token revocation (RFC 7009): an app giving up its access. Always 200, whether or not the
# token was known.
class Oauth::RevocationsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    digest = AccessToken.digest(params[:token].to_s)
    AccessToken.where(token_digest: digest).or(AccessToken.where(refresh_token_digest: digest)).find_each(&:revoke!)
    head :ok
  end
end
