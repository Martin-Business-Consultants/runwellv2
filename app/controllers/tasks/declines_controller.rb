# Declining a task waiting in Intake (Task#decline!): kept, marked done as Declined, out of every
# open list; the client's portal shows it as Declined and nobody is emailed. Answered as accepting is.
class Tasks::DeclinesController < ApplicationController
  include TaskScoped
  include IntakeDecision
  allow_staff
  agent_tool :decline_task, on: :create, title: "Decline a task in intake",
    description: "Decline something waiting in intake (list_intake) that won't be done: it's kept, marked done as Declined, and the client's portal shows it as Declined. Nobody is emailed. note: why, optional, kept as an internal note on it.",
    params: { note: "string" }

  def create
    @task.decline!(by: current_user, note: params[:note])
    answer_decision "Declined “#{@task.title}”."
  rescue Task::Refused => refused
    refuse_decision refused.message
  end
end
