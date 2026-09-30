module AccountManagement
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:account_management) }

    private
      def require_account_manager
        redirect_back fallback_location: account_management_root_path, alert: "Only someone who may manage accounts can do that." unless Current.user.can?(:manage_accounts)
      end
  end
end
