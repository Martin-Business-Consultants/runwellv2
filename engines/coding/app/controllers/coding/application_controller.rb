module Coding
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:coding) }

    private
      def set_todo = @todo = ::Todo.find(params[:todo_id])
  end
end
