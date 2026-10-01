# "Send a test email" on Settings > Email.
class TestMessageMailer < ApplicationMailer
  def check(to:)
    @host = Runwell.host
    mail to: to, subject: "Runwell can send email"
  end
end
