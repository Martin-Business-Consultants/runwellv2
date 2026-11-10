# How an Intake decision (accept or decline, one task or several) answers: in the browser, the
# decided rows leave the Intake table and a toast says so, and from the side panel (inline=panel)
# the page refreshes in place; agents and plain posts get the redirect with its notice.
module IntakeDecision
  extend ActiveSupport::Concern

  private
    def answer_decision(notice, tasks = [ @task ])
      return redirect_back(fallback_location: intake_path, notice: notice) unless request.format.turbo_stream?

      if params[:inline] == "panel"
        flash[:notice] = notice
        render turbo_stream: turbo_stream.refresh(request_id: nil)
      else
        render turbo_stream: tasks.map { turbo_stream.remove(helpers.dom_id(it, :row)) } + [ turbo_stream_flash(notice: notice) ]
      end
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

      render turbo_stream: changed.map { turbo_stream.remove(helpers.dom_id(it, :row)) } + [ turbo_stream_flash(flash_key => message) ]
    end

    def refuse_decision(alert)
      return redirect_back(fallback_location: intake_path, alert: alert) unless request.format.turbo_stream?

      render turbo_stream: turbo_stream_flash(alert: alert), status: :unprocessable_entity
    end
end
