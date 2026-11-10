# Several Intake tasks accepted at once, from its bulk bar: each through Task#accept! as alone (the
# owner picked, else whoever accepts when nobody's on it); one no longer waiting is skipped and named.
class Bulk::Tasks::AcceptancesController < ApplicationController
  include BulkAction
  include IntakeDecision
  allow_staff
  agent_tool :bulk_accept_tasks, on: :create, title: "Accept several tasks from intake",
    description: "ids: tasks waiting in intake (list_intake). owner_id: who owns them (a person's id or name; else you, the person you act for, on any nobody's on). Each leaves intake as accept_task would.",
    params: { ids: "integer[]!", owner_id: "string" }

  def create
    owner = User.people.find_by(id: User.owner_id_for(params[:owner_id], me: current_user.person)) if params[:owner_id].present?
    decide_each("Accepted %{count}") { |task| task.accept!(by: current_user, owner: owner) }
  end
end
