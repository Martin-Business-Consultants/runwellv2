# How an Intake decision (accept or decline, one task or several) answers: in the browser, by
# Turbo Streams wherever it came from (a row, the side panel, the bulk bar): the decided rows leave
# Intake, the task's side panel (closed, when it was decided there) and any Tasks row are redrawn,
# and a toast says so. Agents and plain
# posts get the redirect with its notice.
module IntakeDecision
  extend ActiveSupport::Concern

  private
    def answer_decision(notice, tasks = [ @task ])
      return redirect_back(fallback_location: intake_path, notice: notice) unless request.format.turbo_stream?

      # Each decided task: its Intake row goes and anywhere else it shows is redrawn, wherever the
      # decision came from; never a reload. Decided in the side panel, the panel closes too.
      streams = tasks.flat_map { decided_streams(it) } + [ turbo_stream_flash(notice: notice) ]
      streams << turbo_stream.action(:close_side_panel, "side_panel") if params[:inline] == "panel"
      render turbo_stream: streams
    end

    # Several at once (a BulkAction controller): each task decided as alone, one no longer waiting
    # skipped and named.
    def decide_each(done, &decide)
      tasks = selected(Task.all)
      return refuse_decision("Select at least one first.") if tasks.empty?

      changed, message, flash_key = bulk_results(tasks, done: done) do |task|
        decide.call(task)
        true
      rescue Task::Refused
        "not waiting in intake"
      end
      return redirect_back(fallback_location: intake_path, flash_key => message) unless request.format.turbo_stream?

      render turbo_stream: changed.flat_map { decided_streams(it) } + [ turbo_stream_flash(flash_key => message) ]
    end

    def decided_streams(task)
      task = Task.includes(:owner, :client, :work, :contact, { assignments: :user }, created_by: :agent_owner).find(task.id)
      [ helpers.intake_streams(task),
        turbo_stream.replace(helpers.dom_id(task, :panel), method: :morph, partial: "tasks/panel", locals: { task: task }),
        turbo_stream.replace(helpers.dom_id(task, :row), method: :morph, partial: "tasks/row", locals: { task: task, listed: CustomField.for("Task").listed.to_a }) ]
    end

    def refuse_decision(alert)
      return redirect_back(fallback_location: intake_path, alert: alert) unless request.format.turbo_stream?

      render turbo_stream: turbo_stream_flash(alert: alert), status: :unprocessable_entity
    end
end
