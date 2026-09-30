# Sends one email the way every other message goes out, to prove the sender and the mail
# server work together. In development it lands in letter_opener like everything else.
class Settings::Emails::TestMessagesController < Settings::BaseController
  agent_tool :send_test_email, on: :create, title: "Send a test email", params: { to: "string" }

  def create
    to = params[:to].presence || current_user.email_address
    TestMessageMailer.check(to: to).deliver_now
    redirect_to settings_email_path, notice: "Sent a test email to #{to}."
  rescue StandardError => error
    redirect_to settings_email_path, alert: "Couldn’t send: #{error.message}"
  end
end
