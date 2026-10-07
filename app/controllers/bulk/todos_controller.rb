# Work, many at once: status, owner, due date, whether the client sees it, or remove.
class Bulk::TodosController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_update_work, on: :update, title: "Change several todos at once",
    description: "ids: the todos. Give any of status, owner_id (the lead: a person's id or name, keeping anyone else on it; blank takes everyone off), due_on (blank clears) or client_visible, and each todo changes as update_work would.",
    params: { ids: "integer[]!", todo: { status: Todo::STATUSES, owner_id: "string", due_on: "date", client_visible: "boolean" } }
  agent_tool :bulk_delete_work, on: :destroy, title: "Remove several todos at once", params: { ids: "integer[]!" }

  def update
    changes = params.expect(todo: %i[status owner_id due_on client_visible]).to_h
    if changes.key?("owner_id")
      changes["owner_id"] = owner_id(changes["owner_id"])
      changes["other_owner_ids"] = [] if changes["owner_id"].nil? # Unassigned: nobody on it at all
    end
    return redirect_back(fallback_location: todos_path, alert: "Choose what to change.") if changes.empty?

    apply_to_each(selected(Todo.all), done: "Updated %{count} #{term_for(:work)}", fallback: todos_path) do |todo|
      todo.update(changes) || todo.errors.full_messages.to_sentence
    end
  end

  def destroy
    apply_to_each(selected(Todo.all), done: "Removed %{count} #{term_for(:work)}", fallback: todos_path) do |todo|
      todo.destroy ? true : "it couldn’t be removed"
    end
  end

  private
    def owner_id(value)
      return nil if value.blank? || value == "none"
      return current_user.person.id if value == "me"

      Agent::Resolver.id_for("User", value)
    end

    def term_for(key) = Setting.current.term(key, count: 2).downcase
end
