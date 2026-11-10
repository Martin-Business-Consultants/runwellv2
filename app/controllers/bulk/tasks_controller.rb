# Tasks, many at once: status, owner, due date, whether the client sees it, or remove.
class Bulk::TasksController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_update_tasks, on: :update, title: "Change several tasks at once",
    description: "ids: the tasks. Give any of status, owner_id (the lead: a person's id or name, keeping anyone else on it; blank takes everyone off), due_on (blank clears) or client_visible, and each task changes as update_task would.",
    params: { ids: "integer[]!", task: { status: Task::STATUSES, owner_id: "string", due_on: "date", client_visible: "boolean" } },
    confirm: "Visible to the client (client_visible: true) shows it in their portal.", confirm_when: ->(args) { Agent::Tool.truthy?(args.dig("task", "client_visible")) }
  agent_tool :bulk_delete_tasks, on: :destroy, title: "Remove several tasks at once", params: { ids: "integer[]!" }

  def update
    changes = params.expect(task: %i[status owner_id due_on client_visible]).to_h
    if changes.key?("owner_id")
      changes["owner_id"] = User.owner_id_for(changes["owner_id"], me: current_user.person)
      changes["other_owner_ids"] = [] if changes["owner_id"].nil? # Unassigned: nobody on it at all
    end
    return redirect_back(fallback_location: tasks_path, alert: "Choose what to change.") if changes.empty?

    apply_to_each(selected(Task.all), done: "Updated %{count} #{term_for(:task)}", fallback: tasks_path) do |task|
      task.update(changes) || task.errors.full_messages.to_sentence
    end
  end

  def destroy
    apply_to_each(selected(Task.all), done: "Removed %{count} #{term_for(:task)}", fallback: tasks_path) do |task|
      task.destroy ? true : "it couldn’t be removed"
    end
  end

  private
    def term_for(key) = Setting.current.term(key, count: 2).downcase
end
