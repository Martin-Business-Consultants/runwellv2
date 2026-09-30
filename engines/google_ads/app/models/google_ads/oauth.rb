# Google's OAuth2 dance, and the token refresh that follows it forever after.
#
# Two things about Google's flow shape this code:
#
#   - the refresh token does NOT rotate, and is issued ONLY on a consent that
#     asked for offline access and forced the prompt. Without `prompt=consent`
#     a returning user re-approves and Google sends back an access token and no
#     refresh token at all — the connection then works for one hour.
#   - the redirect URI must match the one registered on the Google Cloud client
#     exactly, including scheme and trailing path.
module GoogleAds
  class Oauth
    require "net/http"
    AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URL     = "https://oauth2.googleapis.com/token"
    REVOKE_URL    = "https://oauth2.googleapis.com/revoke"
    # The whole Google Ads API rides on this one scope; there is no read-only
    # variant. Read-only here is enforced by what this app can ask for — the
    # client only ever issues searchStream — rather than by the grant.
    SCOPE         = "https://www.googleapis.com/auth/adwords"

    class Error < StandardError; end

    def initialize(connection)
      @connection = connection
    end

    attr_reader :connection

    # Where to send someone to say yes. The state is a nonce we check on the way
    # back — without it, anyone can hand a signed-in admin a callback URL and
    # attach THEIR Google Ads manager account to this Runwell.
    def authorize_url(redirect_uri:)
      state = SecureRandom.urlsafe_base64(24)
      connection.update!(oauth_state: state)

      params = {
        client_id: connection.client_id,
        response_type: "code",
        scope: SCOPE,
        redirect_uri: redirect_uri,
        state: state,
        # Offline access is what mints a refresh token; forcing the prompt is
        # what makes Google issue one again for someone who has approved before.
        # Drop either and the connection dies at the first refresh.
        access_type: "offline",
        prompt: "consent",
        include_granted_scopes: "true"
      }
      "#{AUTHORIZE_URL}?#{params.to_query}"
    end

    def exchange_code!(code:, redirect_uri:)
      payload = token_request(
        grant_type: "authorization_code", code: code, redirect_uri: redirect_uri,
        client_id: connection.client_id, client_secret: connection.client_secret
      )

      if payload["refresh_token"].blank? && connection.refresh_token.blank?
        raise Error, "Google approved the sign-in but issued no refresh token. That happens when " \
                     "the account has already approved this app — remove Runwell at " \
                     "myaccount.google.com/permissions and connect again."
      end

      connection.update!(connected_at: Time.current, oauth_state: nil)
      connection.store_tokens!(payload)
      connection
    end

    # A live access token, refreshing first if it is close to expiry.
    def access_token!
      return connection.access_token unless connection.access_expired?
      raise Error, "Google Ads isn't connected — nobody has signed in yet." if connection.refresh_token.blank?

      payload = token_request(
        grant_type: "refresh_token", refresh_token: connection.refresh_token,
        client_id: connection.client_id, client_secret: connection.client_secret
      )
      connection.store_tokens!(payload)
      connection.access_token
    end

    def revoke!
      return if connection.refresh_token.blank?

      post(URI(REVOKE_URL), { token: connection.refresh_token }.to_query,
           "Content-Type" => "application/x-www-form-urlencoded")
    rescue StandardError => e
      # Best effort. Google refusing the revoke must not stop someone
      # disconnecting on this side.
      Rails.logger.warn("[GoogleAds] revoke failed: #{e.message}")
    end

    private

    def token_request(**params)
      response = post(URI(TOKEN_URL), params.to_query,
                      "Content-Type" => "application/x-www-form-urlencoded",
                      "Accept" => "application/json")

      body = begin
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        {}
      end

      unless response.is_a?(Net::HTTPSuccess)
        detail = body["error_description"] || body["error"] || response.body.to_s.truncate(200)
        raise Error, "Google refused the token request (#{response.code}): #{detail}"
      end

      body
    end

    def post(uri, body, headers)
      request = Net::HTTP::Post.new(uri)
      headers.each { |key, value| request[key] = value }
      request.body = body

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end
    end
  end
end
