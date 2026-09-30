# A runner asking for work: the next ready item, with a lease. Answers with the run (its brief,
# task, repositories and limits) or, when there's nothing to do, the reason.
module Factory
  class ClaimsController < ApplicationController
    require_permission :run_agent_work
    agent_tool :claim_work, on: :create, title: "Claim the next piece of work for a runner",
      description: "For runners. Takes the next queued todo (earliest due first) and starts a run with a lease: renew it with heartbeat_run every minute or two, and end it with finish_run. The answer's data.run holds the run id, the task to give the agent, the clone commands and the time limit. With nothing to claim (queue empty, run limit reached, budget used up) the summary says why and there is no data.run. runner: a name for this machine.",
      params: { runner: "string!" }, next_tools: %i[heartbeat_run finish_run]

    def create
      runner = params[:runner].to_s.strip.first(80)
      return redirect_to(factory_root_path, alert: "Give the runner a name.") if runner.blank?

      result = Queue.new.claim!(runner: runner, user: Current.user)
      if result.is_a?(Run)
        redirect_to factory_run_path(result), notice: "#{runner} claimed “#{result.todo.title}” (run #{result.id})."
      else
        redirect_to factory_root_path, notice: "Nothing claimed: #{result.reason}"
      end
    end
  end
end
