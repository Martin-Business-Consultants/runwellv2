class ApplicationMailer < ActionMailer::Base
  # Settings > Email, falling back to MAIL_FROM (Setting#mail_sender).
  default from: -> { Setting.current.mail_sender }

  # Links point at this install's address (Settings > Address, else APP_HOST: Runwell.host).
  def default_url_options = Rails.env.production? ? super.merge(host: Runwell.host, protocol: Runwell.protocol) : super
  layout "mailer"
end
