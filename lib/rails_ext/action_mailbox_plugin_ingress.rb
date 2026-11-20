# Mail in: Action Mailbox's ingresses accept mail only for the service the receiving plugin names
# (Runwell::Plugins.receive_mail), signed with the password it answers. The core receives no mail
# of its own (7.0): with no plugin receiving, every ingress answers 404.
module ActionMailboxPluginIngress
  private
    def ensure_configured
      head :not_found unless Runwell::Plugins.mail_ingress == ingress_name
    end

    def password = Runwell::Plugins.mail_ingress_password
end

Rails.application.config.to_prepare { ActionMailbox::BaseController.prepend(ActionMailboxPluginIngress) }
