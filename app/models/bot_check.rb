require "net/http"

# Asks the provider whether the token a public form sent came from a person (Google reCAPTCHA or
# Cloudflare Turnstile, Setting#bot_check?). A clear "no" refuses the form; when the provider can't
# be reached it lets the form through, logged, so an outage never locks anyone out (the password or
# emailed link still guards the way in).
class BotCheck
  VERIFY_URLS = {
    "recaptcha" => "https://www.google.com/recaptcha/api/siteverify",
    "turnstile" => "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  }.freeze
  # The field each provider's widget adds to the form it sits in.
  TOKEN_PARAMS = { "recaptcha" => "g-recaptcha-response", "turnstile" => "cf-turnstile-response" }.freeze
  SCRIPTS = {
    "recaptcha" => "https://www.google.com/recaptcha/api.js",
    "turnstile" => "https://challenges.cloudflare.com/turnstile/v0/api.js"
  }.freeze
  WIDGET_CLASSES = { "recaptcha" => "g-recaptcha", "turnstile" => "cf-turnstile" }.freeze

  def initialize(setting = Setting.current)
    @setting = setting
  end

  def enabled? = @setting.bot_check?
  def provider = @setting.bot_check_provider
  def token_param = TOKEN_PARAMS.fetch(provider)

  def passed?(token, remote_ip: nil)
    return true unless enabled?
    return false if token.blank?

    response = Net::HTTP.post_form(URI(VERIFY_URLS.fetch(provider)), { secret: @setting.bot_check_secret_key, response: token, remoteip: remote_ip }.compact)
    JSON.parse(response.body)["success"] == true
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError => error
    Rails.logger.warn("[BotCheck] #{provider} unreachable, letting the form through: #{error.class}: #{error.message}")
    true
  end
end
