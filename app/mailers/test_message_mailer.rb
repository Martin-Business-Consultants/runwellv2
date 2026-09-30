# "Send a test email" on Settings > Email.
class TestMessageMailer < ApplicationMailer
  def check(to:)
    @host = ENV.fetch("APP_HOST", "localhost")
    mail to: to, subject: "Runwell can send email"
  end
end
