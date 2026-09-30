class ApplicationMailer < ActionMailer::Base
  # Settings > Email, falling back to MAIL_FROM (Setting#mail_sender).
  default from: -> { Setting.current.mail_sender }
  layout "mailer"
end
