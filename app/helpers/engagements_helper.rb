module EngagementsHelper
  # One line under an engagement's title saying where it stands and what comes next.
  def engagement_next_step(engagement)
    if engagement.closed?
      "#{engagement.state_label} #{l engagement.closed_at.to_date, format: :long}#{": #{engagement.close_reason}" if engagement.close_reason.present?}. Its work and history stay; reopen it if work starts again."
    else
      done, open = engagement.todos.partition { it.status == "done" }.map(&:size)
      work = engagement.todos.none? ? "nothing yet, so add it below" : (open.zero? ? "all done" : "#{open} open, #{done} done")
      "#{term(:work, count: 2)}: #{work}.#{finish_hint(engagement, open)}"
    end
  end

  private
    # All the work done, on fixed scope: time to mark it complete (a recurring service runs on).
    def finish_hint(engagement, open)
      " Everything’s done: mark it complete in Details." if open.zero? && engagement.todos.any? && !engagement.recurring?
    end
end
