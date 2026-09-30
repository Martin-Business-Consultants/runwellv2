# Sends one email through the current mail setup to prove it works. In development it lands
# in letter_opener like everything else.
module Outsend
  class TestMessagesController < ::ApplicationController
    require_permission :manage_settings
    agent_tool :send_outsend_test, on: :create, title: "Send a test email to check Outsend", params: { to: "string" }

    def create
      to = params[:to].presence || current_user.email_address
      TestMailer.check(to: to).deliver_now
      redirect_to outsend_settings_path, notice: "Sent a test email to #{to}."
    rescue StandardError => error
      Connection.note_error!(error.message)
      redirect_to outsend_settings_path, alert: "Couldn’t send: #{error.message}"
    end
  end
end
