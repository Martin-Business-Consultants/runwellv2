module Outsend
  # Routes mail through Outsend while the plugin is on and has a key. As a Mail interceptor it
  # decides per message at delivery time, with the database at hand, so no restart is needed;
  # as an observer it records that a message went out. Development and test mail is left to
  # letter_opener and the test adapter.
  class Delivery
    class << self
      def delivering_email(mail)
        return unless active?
        key = Connection.key or return

        mail.delivery_method(:smtp, Connection.smtp_settings(key))
      end

      def delivered_email(mail)
        Connection.note_delivery! if via_outsend?(mail)
      end

      private
        def active? = !Rails.env.local? && Runwell::Plugins.enabled?(:outsend)

        def via_outsend?(mail)
          method = mail.delivery_method
          method.respond_to?(:settings) && method.settings[:address] == Connection::SMTP[:address]
        end
    end
  end
end
