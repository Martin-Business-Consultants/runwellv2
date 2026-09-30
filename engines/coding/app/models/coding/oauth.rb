module Coding
  # GitHub's OAuth web flow. An OAuth app's tokens don't expire, so there is no refresh; the
  # token lasts until someone disconnects here or revokes it at GitHub.
  class Oauth
    require "net/http"

    AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
    TOKEN_URL = "https://github.com/login/oauth/access_token"
    # repo: pull requests, checks, deployments and collaborators on private repos.
    # admin:repo_hook: adding the webhook for a repo from its panel.
    SCOPE = "repo admin:repo_hook"

    class Error < StandardError; end

    def initialize(connection)
      @connection = connection
    end

    # The state is a nonce checked on the way back, so nobody can hand a signed-in owner a
    # callback that attaches their GitHub account to this Runwell.
    def authorize_url(redirect_uri:)
      state = SecureRandom.urlsafe_base64(24)
      @connection.update!(oauth_state: state)
      "#{AUTHORIZE_URL}?#{{ client_id: @connection.client_id, redirect_uri: redirect_uri, scope: SCOPE, state: state }.to_query}"
    end

    def exchange_code!(code:, redirect_uri:)
      uri = URI(TOKEN_URL)
      response = Net::HTTP.post_form(uri, client_id: @connection.client_id, client_secret: @connection.client_secret, code: code, redirect_uri: redirect_uri)
      payload = Rack::Utils.parse_query(response.body.to_s)
      raise Error, "GitHub refused the sign-in: #{payload["error_description"] || payload["error"] || response.code}" if payload["access_token"].blank?

      @connection.update!(access_token: payload["access_token"], oauth_state: nil, connected_at: Time.current, last_error: nil)
      @connection.update!(login: Github.new(@connection).user["login"])
      @connection
    end

    # Best effort: GitHub refusing must not stop someone disconnecting here.
    def revoke!
      return if @connection.access_token.blank?

      uri = URI("https://api.github.com/applications/#{@connection.client_id}/grant")
      request = Net::HTTP::Delete.new(uri)
      request.basic_auth(@connection.client_id, @connection.client_secret)
      request["Accept"] = "application/vnd.github+json"
      request.body = { access_token: @connection.access_token }.to_json
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { it.request(request) }
    rescue StandardError => e
      Rails.logger.warn("[Coding] revoke failed: #{e.message}")
    end
  end
end
