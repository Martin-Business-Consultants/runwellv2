# The round trip to Intuit's consent screen: create sends someone there, show is where Intuit
# sends them back with a code, the company's realm id and the state we gave them.
module Quickbooks
  class AuthorizationsController < ApplicationController
    require_permission :manage_settings
    agent_exempt :create, :show, reason: "signing in to QuickBooks needs a person in a browser"

    before_action { @connection = Connection.for_settings }

    def create
      return redirect_to(quickbooks_settings_path, alert: "Save your Intuit client id and secret first.") unless @connection.configured?

      redirect_to Oauth.new(@connection).authorize_url(redirect_uri: quickbooks_authorization_url), allow_other_host: true
    end

    def show
      return redirect_to(quickbooks_settings_path, alert: "Intuit declined: #{params[:error]}") if params[:error].present?

      unless params[:state].present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, @connection.oauth_state.to_s)
        return redirect_to quickbooks_settings_path, alert: "That sign-in didn’t start here. Try again."
      end

      Oauth.new(@connection).exchange_code!(code: params[:code], realm_id: params[:realmId], redirect_uri: quickbooks_authorization_url)
      @connection.update!(company_name: Api.new(@connection).company&.dig("CompanyName"))
      SyncJob.perform_later
      redirect_to quickbooks_settings_path, notice: "Connected to #{@connection.company_name || "QuickBooks"}. Now choose the product or service for invoice lines."
    rescue Oauth::Error, Api::Error => e
      redirect_to quickbooks_settings_path, alert: e.message
    end
  end
end
