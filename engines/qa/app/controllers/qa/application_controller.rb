module Qa
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:qa) }

    helper_method :can_edit_check?

    private
      # The check's owner answers for it, so they can keep its source of truth; so can anyone
      # who may manage QA.
      def can_edit_check?(check) = Current.user.can?(:manage_qa) || check.owner == Current.user

      def require_check_editor
        redirect_back fallback_location: qa_check_path(@check), alert: "Only the check’s owner, or someone who may manage QA, can change it." unless can_edit_check?(@check)
      end

      def set_check = @check = Check.find(params[:check_id] || params[:id])
  end
end
