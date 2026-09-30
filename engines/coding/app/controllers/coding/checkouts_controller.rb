# A todo's workspace: the repos to clone, the branch to work on, how to set up, and what was
# agreed. The page shows the commands; an agent calls checkout_work and runs them.
module Coding
  class CheckoutsController < ApplicationController
    allow_staff
    agent_tool :checkout_work, on: :show, title: "Get everything needed to start a todo locally",
      description: "The repos to clone (inherited from the engagement or client when the todo has none), the branch to work on, setup notes, environments, and the context: the todo, its scope item, the agreed scope as the client approved it, open commitments, recent notes and documents. Clone and switch to the branch, then report with log_progress and finish_work. If the work goes beyond the agreed scope, say so with flag_out_of_scope.",
      next_tools: %i[log_progress finish_work flag_out_of_scope]

    before_action :set_todo

    def show
      @workspace = Workspace.new(@todo)
    end
  end
end
