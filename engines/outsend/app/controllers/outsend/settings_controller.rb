# Settings > Outsend: the API key, and whether mail is getting through.
module Outsend
  class SettingsController < ::ApplicationController
    require_permission :manage_settings
    agent_tool :show_outsend_settings, on: :show, title: "Show the Outsend mail connection"
    agent_tool :update_outsend_settings, on: :update, title: "Save the Outsend API key",
      description: "api_key: from the Outsend account. Who mail comes from is the install's sender (update_email_settings), on a domain Outsend can send for.",
      params: { connection: { api_key: "string!" } }
    agent_tool :forget_outsend_key, on: :destroy, title: "Forget the saved Outsend API key"

    before_action :set_connection

    def show
    end

    def update
      key = params.expect(connection: [ :api_key ])[:api_key].to_s.strip
      return redirect_to outsend_settings_path, alert: "Paste the API key." if key.blank?

      if @connection.update(api_key: key)
        redirect_to outsend_settings_path, notice: "Saved. Send a test email to check it."
      else
        redirect_to outsend_settings_path, alert: @connection.errors.full_messages.to_sentence
      end
    end

    def destroy
      @connection.forget_key! if @connection.persisted?
      redirect_to outsend_settings_path, notice: "Forgot the Outsend key."
    end

    private
      def set_connection = @connection = Connection.for_settings
  end
end
