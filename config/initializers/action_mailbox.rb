# Requests by email: Action Mailbox takes the inbound service and its password from the server's
# environment (config/environments/production.rb, RAILS_INBOUND_EMAIL_PASSWORD) and, failing that,
# from the install's settings (Setting.inbound_ingress, Setting.inbound_password), which Settings >
# Email and plugins set without a restart.
Rails.application.config.to_prepare do
  ActionMailbox::BaseController.prepend(Module.new do
    private
      def ensure_configured
        head :not_found unless Setting.inbound_ingress == ingress_name
      end

      def password = Setting.inbound_password
  end)
end
