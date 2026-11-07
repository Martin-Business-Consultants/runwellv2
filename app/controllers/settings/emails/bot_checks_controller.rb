# The bot check on the public forms (BotCheck): Settings > Email > Bot checks.
class Settings::Emails::BotChecksController < Settings::BaseController
  agent_exempt :update, reason: "a provider's secret key is entered by a person in the browser"

  def update
    attributes = params.expect(bot_check: %i[bot_check_provider bot_check_site_key bot_check_secret_key])
    attributes.delete(:bot_check_secret_key) if attributes[:bot_check_secret_key].blank? && attributes[:bot_check_provider].present?
    setting = Setting.current

    if setting.update(attributes)
      setting.record_event!("settings.bot_check", payload: { provider: setting.bot_check_provider, on: setting.bot_check? })
      message = setting.bot_check? ? "Bot checks are on, with #{Setting::BOT_CHECK_PROVIDERS[setting.bot_check_provider]}." : "Bot checks are off."
      redirect_to settings_email_path(tab: "bots"), notice: message
    else
      redirect_to settings_email_path(tab: "bots"), alert: setting.errors.full_messages.to_sentence
    end
  end
end
