module Factory
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:factory) }

    private
      def set_todo = @todo = ::Todo.find(params[:todo_id])
      def set_run = @run = Run.includes(:item, todo: { engagement: :client }).find(params[:run_id] || params[:id])

      # A runner reports only on the runs it claimed.
      def require_claimant
        head :forbidden unless @run.reportable_by?(Current.user)
      end
  end
end
