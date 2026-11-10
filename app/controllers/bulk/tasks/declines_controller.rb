# Several Intake tasks declined at once, from its bulk bar: each through Task#decline! as alone.
class Bulk::Tasks::DeclinesController < ApplicationController
  include BulkAction
  include IntakeDecision
  allow_staff
  agent_tool :bulk_decline_tasks, on: :create, title: "Decline several tasks in intake",
    description: "ids: tasks waiting in intake (list_intake) that won't be done. Each is kept, marked done as Declined, as decline_task would; nobody is emailed.",
    params: { ids: "integer[]!" }

  def create
    decide_each("Declined %{count}") { |task| task.decline!(by: current_user) }
  end
end
