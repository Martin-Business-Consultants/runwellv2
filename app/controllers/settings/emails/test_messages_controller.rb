# Sends one email the way every other message goes out, to prove the sender and the mail
# server work together. In development it lands in letter_opener like everything else.
class Settings::Emails::TestMessagesController < Settings::BaseController
  agent_tool :send_test_email, on: :create, title: "Send a test email",
    description: "Sends from a job; show_email_settings says whether it went, or the mail server's error.", params: { to: "string" }

  def create
    to = params[:to].presence || current_user.email_address
    TestEmailJob.send_later(to)
    redirect_to settings_email_path, notice: "Sending a test email to #{to}. This page says how it went."
  end
end
