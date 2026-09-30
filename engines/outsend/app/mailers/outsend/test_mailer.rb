module Outsend
  # "Send a test email" on Settings > Outsend.
  class TestMailer < ::ApplicationMailer
    def check(to:)
      @host = ENV.fetch("APP_HOST", "localhost")
      mail to: to, subject: "Runwell can send email"
    end
  end
end
