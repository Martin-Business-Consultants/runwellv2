# The outgoing mail server, saved in the app when the environment names none (Settings > Email).
class Settings::Emails::SmtpsController < Settings::BaseController
  agent_exempt :update, reason: "a mail server's password is entered by a person in the browser"

  def update
    attributes = params.expect(smtp: %i[smtp_address smtp_port smtp_username smtp_password smtp_security])
    attributes.delete(:smtp_password) if attributes[:smtp_password].blank?
    setting = Setting.current

    if setting.update(attributes)
      message = setting.smtp_address ? "Mail goes out through #{setting.smtp_address}. Send a test email to check it." : "No mail server is saved."
      redirect_to settings_email_path, notice: message
    else
      redirect_to settings_email_path, alert: setting.errors.full_messages.to_sentence
    end
  end
end
