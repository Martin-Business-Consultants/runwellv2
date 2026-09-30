# The round trip to Google's consent screen: create sends someone there, show is where
# Google sends them back with a code and the state we gave them.
module GoogleAds
  class AuthorizationsController < ApplicationController
    require_permission :manage_settings
    agent_exempt :create, :show, reason: "signing in to Google needs a person in a browser"

    before_action :set_connection

    def create
      return redirect_to(google_ads_settings_path, alert: "Save your client id, secret and developer token first.") unless @connection.configured?

      redirect_to Oauth.new(@connection).authorize_url(redirect_uri: redirect_uri), allow_other_host: true
    end

    def show
      return redirect_to(google_ads_settings_path, alert: "Google declined: #{params[:error]}") if params[:error].present?

      # Without the state check, someone could hand a signed-in owner a callback URL and attach
      # THEIR Google Ads manager account to this Runwell.
      unless params[:state].present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, @connection.oauth_state.to_s)
        return redirect_to google_ads_settings_path, alert: "That sign-in didn’t start here. Try again."
      end

      Oauth.new(@connection).exchange_code!(code: params[:code], redirect_uri: redirect_uri)
      SyncJob.perform_later
      redirect_to google_ads_settings_path, notice: "Connected. Pulling in ad spend now."
    rescue Oauth::Error => e
      redirect_to google_ads_settings_path, alert: e.message
    end

    private
      def set_connection = @connection = Connection.for_settings

      # Must match a redirect URI registered on the Google Cloud OAuth client exactly.
      def redirect_uri = google_ads_authorization_url
  end
end
