# OAuth discovery, so a connector (Claude, ChatGPT) can find how to sign in on its own:
# the protected resource (RFC 9728) points at the authorization server (RFC 8414).
class Oauth::MetadataController < ApplicationController
  allow_unauthenticated_access

  # The staff MCP endpoint, or a client's portal one (/.well-known/oauth-protected-resource/portal/mcp).
  def protected_resource
    portal = params[:resource].to_s.start_with?("portal")
    render json: { resource: portal ? portal_mcp_url : mcp_url, authorization_servers: [ root_url.chomp("/") ], bearer_methods_supported: [ "header" ],
      resource_name: portal ? "#{Setting.current.brand_name} client portal" : "Runwell",
      scopes_supported: portal ? [ "runwell:portal", "runwell:read" ] : [ "runwell", "runwell:read" ] }
  end

  def authorization_server
    render json: {
      issuer: root_url.chomp("/"),
      authorization_endpoint: oauth_authorization_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_clients_url,
      revocation_endpoint: oauth_revocation_url,
      response_types_supported: [ "code" ],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: [ "S256" ],
      token_endpoint_auth_methods_supported: [ "none" ],
      scopes_supported: [ "runwell", "runwell:read", "runwell:portal" ]
    }
  end
end
