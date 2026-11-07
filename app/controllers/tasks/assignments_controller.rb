# The owner picker's click (Fizzy's assignments): puts a person on the task, or takes them off.
# The first on leads; taking off the lead hands it to whoever came on next. The menu stays open,
# and the answer replaces the avatars beside it.
class Tasks::AssignmentsController < ApplicationController
  allow_staff
  agent_exempt :create, reason: "The owner picker's toggle. Agents set the lead with update_task's owner_id and everyone else with other_owner_ids."

  def create
    task = Task.find(params[:task_id])
    person = User.active.people.find(params[:assignee_id])
    task.toggle_assignment!(person)
    task = Task.includes(:owner, assignments: :user).find(task.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(helpers.dom_id(task, params[:labelled].present? ? :owners_labelled : :owners),
          partial: "tasks/owners", locals: { task: task, labelled: params[:labelled].present? })
      end
      format.html { redirect_back fallback_location: task_path(task), notice: "#{person.display_name} #{task.assigned_to?(person) ? "is on" : "is off"} it." }
    end
  end
end
