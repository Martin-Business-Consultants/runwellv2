# A client's reply on a task's discussion, from the side sheet in the portal: a note on the task,
# shared (client_visible), written by the client's own person. Staff see it in the task's notes.
# From the sheet (inline=discussion) the answer redraws the discussion in place; anyone else (their
# agent, a plain form) is sent back.
class Portal::Tasks::NotesController < Portal::BaseController
  agent_tool :portal_reply_on_task, on: :create, title: "Reply on a task",
    description: "A message on one of the tasks shared with you, in its discussion: the team sees it on the task. Show the person what you'll send first.",
    params: { note: { body: "text!" } }

  def create
    task = client.tasks.client_visible.find(params[:task_id])
    note = task.notes.new(body: params.expect(note: [ :body ])[:body], kind: "internal", client_visible: true,
      author: current_contact, source: Current.client_agent? ? "agent" : "portal")
    if note.save
      return render(turbo_stream: [ turbo_stream.replace(helpers.dom_id(task, :portal_discussion), method: :morph, partial: "portal/tasks/discussion", locals: { task: task }),
                                    turbo_stream_flash(notice: "Sent.") ]) if inline?("discussion")

      redirect_back fallback_location: portal_tasks_path(task: task.id), notice: "Sent."
    else
      return refuse_in_place(note.errors.full_messages.to_sentence) if inline?("discussion")

      redirect_back fallback_location: portal_tasks_path(task: task.id), alert: note.errors.full_messages.to_sentence
    end
  end
end
