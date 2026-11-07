# A check that a person, not a bot, sent the sign-in, sign-up and password reset forms (BotCheck):
# the provider and its keys, from Settings > Email > Bot checks. Off until all three are set.
module Setting::BotCheck
  extend ActiveSupport::Concern

  BOT_CHECK_PROVIDERS = { "recaptcha" => "Google reCAPTCHA (v2, the checkbox)", "turnstile" => "Cloudflare Turnstile" }.freeze

  included do
    encrypts :bot_check_secret_key
    normalizes :bot_check_provider, :bot_check_site_key, :bot_check_secret_key, with: ->(value) { value.to_s.strip.presence }
    validates :bot_check_provider, inclusion: { in: BOT_CHECK_PROVIDERS.keys }, allow_nil: true
  end

  def bot_check? = bot_check_provider.present? && bot_check_site_key.present? && bot_check_secret_key.present?
end
