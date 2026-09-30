# Settings > Email: who the install's mail comes from, and how it goes out.
class Settings::EmailsController < Settings::BaseController
  agent_tool :show_email_settings, on: :show, title: "Show who mail comes from and how it is sent"
  agent_tool :update_email_settings, on: :update, title: "Set who mail comes from",
    description: "from_name and from_email: the sender on every email Runwell sends, on a domain the mail server can send for. Blank uses the default sender (MAIL_FROM, or no-reply at the install's host).",
    params: { setting: { mail_from_name: "string", mail_from_email: "string" } }

  def show
    @setting = Setting.current
  end

  def update
    @setting = Setting.current

    if @setting.update(params.expect(setting: %i[mail_from_name mail_from_email]))
      redirect_to settings_email_path, notice: "Mail now comes from #{@setting.mail_sender}."
    else
      redirect_to settings_email_path, alert: @setting.errors.full_messages.to_sentence
    end
  end
end
