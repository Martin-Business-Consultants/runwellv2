# Dynamic client registration (RFC 7591): a connector registers itself before asking a person
# to approve it. Public clients only (no secret); they prove themselves with PKCE.
class Oauth::ClientsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  rate_limit to: 20, within: 1.hour, only: :create

  def create
    client = OauthClient.new(name: params[:client_name].presence || "An AI app", redirect_uris: Array(params[:redirect_uris]))
    if client.save
      render status: :created, json: {
        client_id: client.uid, client_name: client.name, redirect_uris: client.redirect_uris,
        token_endpoint_auth_method: "none", grant_types: %w[authorization_code refresh_token], response_types: [ "code" ]
      }
    else
      render status: :bad_request, json: { error: "invalid_redirect_uri", error_description: client.errors.full_messages.to_sentence }
    end
  end
end
