module WorksHelper
  # One line under a piece of work's title saying where it stands and what comes next.
  def work_next_step(work)
    if work.closed?
      "#{work.state_label} #{l work.closed_at.to_date, format: :long}#{": #{work.close_reason}" if work.close_reason.present?}. Its work and history stay; reopen it if work starts again."
    else
      done, open = work.tasks.partition { it.status == "done" }.map(&:size)
      progress = work.tasks.none? ? "nothing yet, so add it below" : (open.zero? ? "all done" : "#{open} open, #{done} done")
      "#{term(:task, count: 2)}: #{progress}.#{finish_hint(work, open)}"
    end
  end

  private
    # All the work done, on fixed scope: time to mark it complete (a recurring service runs on).
    def finish_hint(work, open)
      " Everything’s done: mark it complete in Details." if open.zero? && work.tasks.any? && !work.recurring?
    end
end
