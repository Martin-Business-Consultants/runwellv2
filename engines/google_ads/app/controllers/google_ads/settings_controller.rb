# Settings > Google Ads: the agency's credentials, signing in to Google, who gets stopped-
# account alerts, and every linked account with its latest month.
module GoogleAds
  class SettingsController < ApplicationController
    require_permission :manage_settings
    agent_tool :show_google_ads_settings, on: :show, title: "Show the Google Ads connection and linked accounts"
    agent_tool :update_google_ads_settings, on: :update, title: "Change Google Ads credentials and alert addresses",
      params: { connection: { client_id: "string", client_secret: "string", developer_token: "string", login_customer_id: "string", alert_recipients: "string" } }
    agent_tool :disconnect_google_ads, on: :destroy, title: "Disconnect Google Ads"

    before_action :set_connection

    def show
      @links = Link.includes(:account, engagement: :client).order(:customer_id)
      @latest = Spend.latest_by_account(@links.map(&:customer_id))
      @accessible = accessible_accounts
    end

    def update
      if @connection.update(connection_params)
        redirect_to google_ads_settings_path, notice: @connection.connected? ? "Saved." : "Saved. Now sign in with Google to connect."
      else
        redirect_to google_ads_settings_path, alert: @connection.errors.full_messages.to_sentence
      end
    end

    def destroy
      Oauth.new(@connection).revoke!
      @connection.disconnect!
      redirect_to google_ads_settings_path, notice: "Disconnected from Google Ads."
    end

    private
      def set_connection = @connection = Connection.for_settings

      # Secrets are write-only on the page: a blank field keeps what is saved.
      def connection_params
        params.expect(connection: %i[client_id client_secret developer_token login_customer_id alert_recipients])
          .reject { |key, value| key.in?(%w[client_secret developer_token]) && value.blank? }
      end

      # The ad accounts this login can reach, "Name · 123-456-7890", for picking rather than
      # typing an id. Asking Google also proves the connection works.
      def accessible_accounts
        return [] unless @connection.connected?

        client = Client.new(@connection)
        ids = client.accessible_customers
        names = Account.where(customer_id: ids).where.not(descriptive_name: [ nil, "" ]).pluck(:customer_id, :descriptive_name).to_h
        @connection.clear_error!
        ids.map { |id| [ [ names[id], Client.format_customer_id(id) ].compact.join(" · "), id ] }.sort_by { it.first.downcase }
      rescue Client::Error, Oauth::Error => e
        @connection.note_error!(e.message)
        []
      end
  end
end
