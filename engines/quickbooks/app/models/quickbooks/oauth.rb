module Quickbooks
  # Intuit's OAuth2 flow, and the token refresh that follows it forever after. The refresh
  # token ROTATES on every use, so the new one must be saved or the connection dies at the next
  # refresh; and the redirect URI must match the one registered on the Intuit app exactly.
  class Oauth
    require "net/http"

    AUTHORIZE_URL = "https://appcenter.intuit.com/connect/oauth2"
    TOKEN_URL = "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
    REVOKE_URL = "https://developer.api.intuit.com/v2/oauth2/tokens/revoke"
    SCOPE = "com.intuit.quickbooks.accounting"

    class Error < StandardError; end

    def initialize(connection)
      @connection = connection
    end

    attr_reader :connection

    # The state is a nonce checked on the way back: without it, anyone could hand a signed-in
    # owner a callback URL and attach their own QuickBooks company to this Runwell.
    def authorize_url(redirect_uri:)
      state = SecureRandom.urlsafe_base64(24)
      connection.update!(oauth_state: state)
      "#{AUTHORIZE_URL}?#{{ client_id: connection.client_id, response_type: "code", scope: SCOPE, redirect_uri: redirect_uri, state: state }.to_query}"
    end

    # Intuit sends back a code and the realm (company) id.
    def exchange_code!(code:, realm_id:, redirect_uri:)
      payload = token_request(grant_type: "authorization_code", code: code, redirect_uri: redirect_uri)
      connection.update!(realm_id: realm_id, connected_at: Time.current, oauth_state: nil)
      connection.store_tokens!(payload)
      connection
    end

    def access_token!
      return connection.access_token unless connection.access_expired?
      raise Error, "QuickBooks needs reconnecting: the refresh token has expired." if connection.refresh_expired?

      connection.store_tokens!(token_request(grant_type: "refresh_token", refresh_token: connection.refresh_token))
      connection.access_token
    end

    # Best effort: Intuit refusing must not stop someone disconnecting here.
    def revoke!
      return if connection.refresh_token.blank?

      post(URI(REVOKE_URL), { token: connection.refresh_token }.to_json, "Content-Type" => "application/json", "Authorization" => basic_auth)
    rescue StandardError => e
      Rails.logger.warn("[Quickbooks] revoke failed: #{e.message}")
    end

    private
      def token_request(**params)
        response = post(URI(TOKEN_URL), params.to_query, "Content-Type" => "application/x-www-form-urlencoded",
          "Accept" => "application/json", "Authorization" => basic_auth)
        body = begin
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          {}
        end
        raise Error, "Intuit refused the token request (#{response.code}): #{body["error_description"] || body["error"] || response.body}" unless response.is_a?(Net::HTTPSuccess)

        body
      end

      def basic_auth = "Basic #{Base64.strict_encode64("#{connection.client_id}:#{connection.client_secret}")}"

      def post(uri, body, headers)
        request = Net::HTTP::Post.new(uri)
        headers.each { |key, value| request[key] = value }
        request.body = body
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { it.request(request) }
      end
  end
end
