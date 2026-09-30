# The round trip to GitHub's consent screen: create sends someone there, show is where GitHub
# sends them back with a code and the state we gave them.
module Coding
  class AuthorizationsController < ApplicationController
    require_permission :manage_settings
    agent_exempt :create, :show, reason: "signing in to GitHub needs a person in a browser"

    before_action { @connection = Connection.for_settings }

    def create
      return redirect_to(coding_settings_path, alert: "Save your OAuth client id and secret first.") unless @connection.configured?

      redirect_to Oauth.new(@connection).authorize_url(redirect_uri: coding_authorization_url), allow_other_host: true
    end

    def show
      return redirect_to(coding_settings_path, alert: "GitHub declined: #{params[:error_description] || params[:error]}") if params[:error].present?

      unless params[:state].present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, @connection.oauth_state.to_s)
        return redirect_to coding_settings_path, alert: "That sign-in didn’t start here. Try again."
      end

      Oauth.new(@connection).exchange_code!(code: params[:code], redirect_uri: coding_authorization_url)
      SyncJob.perform_later
      redirect_to coding_settings_path, notice: "Connected to GitHub as #{@connection.login}."
    rescue Oauth::Error, Github::Error => e
      redirect_to coding_settings_path, alert: e.message
    end
  end
end
