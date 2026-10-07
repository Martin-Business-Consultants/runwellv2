# The owner picker's click (Fizzy's assignments): puts a person on the work, or takes them off.
# The first on leads; taking off the lead hands it to whoever came on next. The menu stays open,
# and the answer replaces the avatars beside it.
class Todos::AssignmentsController < ApplicationController
  allow_staff
  agent_exempt :create, reason: "The owner picker's toggle. Agents set the lead with update_work's owner_id and everyone else with other_owner_ids."

  def create
    todo = Todo.find(params[:todo_id])
    person = User.active.people.find(params[:assignee_id])
    todo.toggle_assignment!(person)
    todo = Todo.includes(:owner, assignments: :user).find(todo.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(helpers.dom_id(todo, params[:labelled].present? ? :owners_labelled : :owners),
          partial: "todos/owners", locals: { todo: todo, labelled: params[:labelled].present? })
      end
      format.html { redirect_back fallback_location: todo_path(todo), notice: "#{person.display_name} #{todo.assigned_to?(person) ? "is on" : "is off"} it." }
    end
  end
end
