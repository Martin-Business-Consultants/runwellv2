# Accepting a task waiting in Intake (Task#accept!): someone owns it now (the owner picked, else
# whoever accepts), and it leaves Intake even before it's on a piece of work. From an Intake row its
# row goes; from the side panel the page refreshes in place; anything else is redirected back.
class Tasks::AcceptancesController < ApplicationController
  include TaskScoped
  include IntakeDecision
  allow_staff
  agent_tool :accept_task, on: :create, title: "Accept a task from intake",
    description: "Take on something waiting in intake (list_intake): owner_id is who owns it (a person's id or name; you, the person you act for, when nobody's on it). It leaves intake even if it isn't on a piece of work yet; update_task with work_id files it.",
    params: { owner_id: "string" }, next_tools: %i[update_task]

  def create
    owner = User.people.find_by(id: User.owner_id_for(params[:owner_id], me: current_user.person)) if params[:owner_id].present?
    @task.accept!(by: current_user, owner: owner)
    answer_decision "Accepted “#{@task.title}”#{" for #{@task.owner.display_name}" if @task.owner && @task.owner != current_user.person}."
  rescue Task::Refused => refused
    refuse_decision refused.message
  end
end
