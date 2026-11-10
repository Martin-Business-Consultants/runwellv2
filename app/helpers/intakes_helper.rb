module IntakesHelper
  # Intake's part of any answer about a task (Turbo Streams; a target the page lacks is skipped):
  # its Intake row redrawn while it's still waiting, or removed once it isn't (accepted, declined,
  # done, or owned and on a piece of work), and the side panel's Intake bar redrawn. Every stream
  # that changes a task adds it, so Intake and the panel never wait for a reload.
  def intake_streams(task)
    row = if task.intake?
      turbo_stream.replace(dom_id(task, :intake), method: :morph, partial: "intakes/row", locals: { task: task })
    else
      turbo_stream.remove(dom_id(task, :intake))
    end
    safe_join([ row, turbo_stream.replace(dom_id(task, :intake_bar), partial: "intakes/bar", locals: { task: task }) ])
  end
end
