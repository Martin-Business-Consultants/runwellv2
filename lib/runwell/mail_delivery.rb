# Outgoing mail through the server saved in Settings > Email, when the environment names none
# (SMTP_ADDRESS sets ActionMailer's own delivery in production.rb, and wins). Registered as an
# interceptor in config/application.rb. Decided per message,
# so saving the settings needs no restart. A plugin that routes mail itself (Outsend) has already
# set a real delivery method by the time this runs, and is left alone: only a message still headed
# for the placeholder (:test in production without SMTP) is given the saved server.
module Runwell
  module MailDelivery
    def self.delivering_email(mail)
      return unless Rails.env.production? && mail.delivery_method.is_a?(Mail::TestMailer)
      return unless (settings = Setting.current.smtp_settings)

      mail.delivery_method(:smtp, settings)
    end
  end
end
