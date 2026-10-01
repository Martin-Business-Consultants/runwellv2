class ApplicationMailer < ActionMailer::Base
  # Settings > Email, falling back to MAIL_FROM (Setting#mail_sender).
  default from: -> { Setting.current.mail_sender }

  # Links point at this install's address (Runwell.host): APP_HOST, else the one people use.
  def default_url_options = Rails.env.production? ? super.merge(host: Runwell.host) : super
  layout "mailer"
end
