# One run: who took what, where it's got to, what it cost. For a runner, also the task, brief
# and repositories it works from.
module Factory
  class RunsController < ApplicationController
    allow_staff
    agent_tool :show_run, on: :show, title: "Show an agent run",
      description: "Its status, runner, todo, lease and deadline, branch and pull request, summary or error, and cost. For the runner that claimed it: the task to give the agent (with the brief) and the repositories with their clone commands."

    before_action :set_run

    def show
      @claimant = @run.reportable_by?(Current.user)
      @brief = ::Todo::Brief.new(@run.todo, base_url: request.base_url, person: Current.user) if @claimant
      @workspace = Coding::Workspace.new(@run.todo) if @claimant && Runwell::Plugins.enabled?(:coding)
    end
  end
end
