# A task's status, changed in place from its picker anywhere (a list, the board's table, the side
# panel, its own page). The answer replaces every place the task can be on the page; a target the
# page doesn't have is left alone. In a Tasks list (data-task-list, which the picker sends with
# its choice) that list comes back too, so a task marked done leaves Open at once.
class Tasks::StatusesController < ApplicationController
  include TaskScoped
  allow_staff
  agent_exempt :update, reason: "the status picker in the browser; update_task changes status"

  # Marking it done offers Undo in the toast for a few seconds: the same request with the status it
  # had and undo, which puts it back (Task#undo_done!, taking the next one a repeat made with it).
  def update
    before = @task.status
    if params[:undo].present? && @task.status == "done"
      @undone = true
      @notice = [ "#{@task.title}: back to #{params.dig(:task, :status).to_s.humanize.downcase}.", @task.undo_done!(params.dig(:task, :status)) ].compact.join(" ")
    elsif @task.update(status: params.dig(:task, :status))
      @notice = "#{@task.title}: #{@task.status.humanize.downcase}."
      @notice = undo_status(@notice, before) if @task.status == "done" && before != "done"
    else
      @alert = @task.errors.full_messages.to_sentence
      @task.reload
    end
    @list = Task::List.from(params.fetch(:list, {}), task: @task)
  rescue ActiveRecord::RecordInvalid => e
    @alert = e.record.errors.full_messages.to_sentence
    @task.reload
    @list = Task::List.from(params.fetch(:list, {}), task: @task)
  end

  private
    def undo_status(text, before)
      { title: text, duration: PendingRemoval::WINDOW.in_milliseconds,
        action: { label: "Undo", url: task_status_path(@task), method: :patch, params: { "task[status]" => before, undo: 1 } } }
    end
end
