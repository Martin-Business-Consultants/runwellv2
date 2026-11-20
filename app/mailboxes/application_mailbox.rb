# Mail reaches Runwell only through the inbound service a plugin sets up (Runwell::Plugins.receive_mail,
# 7.0), and that plugin's mailbox processes every message. With no such plugin switched on the
# ingresses answer 404 (ActionMailboxPluginIngress), and anything already taken in is bounced.
class ApplicationMailbox < ActionMailbox::Base
  def self.route(inbound_email)
    if (mailbox = Runwell::Plugins.mail_receiver&.dig(:mailbox))
      mailbox.to_s.constantize.receive(inbound_email)
    else
      inbound_email.bounced!
    end
  end
end
