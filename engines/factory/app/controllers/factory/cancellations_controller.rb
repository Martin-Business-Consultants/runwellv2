# A person stopping a run. The runner learns at its next heartbeat and stops the agent.
module Factory
  class CancellationsController < ApplicationController
    require_permission :queue_agent_work
    agent_tool :cancel_run, on: :create, title: "Stop an agent run",
      description: "Ends the run as cancelled and puts the todo back to planned. The runner stops the agent at its next heartbeat. The todo stays queued; take it back with unqueue_work."

    before_action :set_run

    def create
      return redirect_back(fallback_location: factory_run_path(@run), alert: "Run #{@run.id} already ended.") unless @run.running?

      @run.cancel!(by: Current.user)
      redirect_back fallback_location: factory_run_path(@run), notice: "Run #{@run.id} cancelled. The runner stops at its next check-in."
    end
  end
end
