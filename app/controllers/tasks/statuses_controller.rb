# A task's status, changed in place from its picker anywhere (a list, the board's table, the side
# panel, its own page). The answer replaces every place the task can be on the page; a target the
# page doesn't have is left alone. In a Tasks list (data-task-list, which the picker sends with
# its choice) that list comes back too, so a task marked done leaves Open at once.
class Tasks::StatusesController < ApplicationController
  include TaskScoped
  allow_staff
  agent_exempt :update, reason: "the status picker in the browser; update_task changes status"

  def update
    if @task.update(status: params.dig(:task, :status))
      @notice = "#{@task.title}: #{@task.status.humanize.downcase}."
    else
      @alert = @task.errors.full_messages.to_sentence
      @task.reload
    end
    @list = Task::List.from(params.fetch(:list, {}), task: @task)
  end
end
