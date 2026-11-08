module WorksHelper
  # A piece of work's tabs, with their counts and plugins' panels (works/_record_tab).
  def work_record_tabs(work)
    [
      record_tab("tasks", term(:task, count: 2), count: work.tasks.open.count),
      record_tab("notes", "Notes", count: work.notes.count),
      record_tab("documents", "Documents", count: work.documents.count),
      record_tab("history", "History")
    ] + plugin_record_tabs(:work_panel)
  end

  # One line under a piece of work's title saying where it stands and what comes next.
  def work_next_step(work)
    if work.closed?
      "#{work.state_label} #{l work.closed_at.to_date, format: :long}#{": #{work.close_reason}" if work.close_reason.present?}. Its work and history stay; reopen it if work starts again."
    else
      done, open = work.task_progress
      progress = (done + open).zero? ? "nothing yet, so add it below" : (open.zero? ? "all done" : "#{open} open, #{done} done")
      "#{term(:task, count: 2)}: #{progress}.#{finish_hint(work, open)}"
    end
  end

  private
    # All the work done, on fixed scope: time to mark it complete (a recurring service runs on).
    def finish_hint(work, open)
      " Everything’s done: mark it complete in Details." if open.zero? && work.tasks.any? && !work.recurring?
    end
end
