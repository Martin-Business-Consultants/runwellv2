# A client's reply on a task's discussion, from the side sheet in the portal: a note on the task,
# shared (client_visible), written by the client's own person, with any files they sent as the
# task's documents. Whoever is on the task hears (Notifier::ClientReplyNotifier). From the sheet
# (inline=discussion) the answer redraws the task in place; anyone else (their agent, a plain form)
# is sent back.
class Portal::Tasks::NotesController < Portal::BaseController
  include PortalUploads

  agent_tool :portal_reply_on_task, on: :create, title: "Reply on a task",
    description: "A message on one of the tasks shared with you, in its discussion: the team sees it on the task and is told. files: anything to send with it.",
    params: { note: { body: "text", files: "file[]" } },
    confirm: "It goes to the team in the person’s name, on the task. Show them what you’ll send first."

  def create
    task = client.tasks.client_visible.find(params[:task_id])
    sent = params.expect(note: [ :body, files: [] ])
    files = Array(sent[:files]).select { it.respond_to?(:original_filename) }
    # Files alone are a message too: it says what was sent.
    body = sent[:body].presence || ("Sent #{files.map(&:original_filename).to_sentence}." if files.any?)
    note = task.notes.new(body: body, kind: "internal", client_visible: true,
      author: current_contact, source: Current.client_agent? ? "agent" : "portal")
    if note.save
      notice = "Sent.#{refused_files_notice(attach_portal_files(task, files))}"
      task.discussion_read_by!(current_contact)
      return render(turbo_stream: [ turbo_stream.replace(helpers.dom_id(task, :portal_panel), method: :morph, partial: "portal/tasks/panel", locals: { task: task.reload }),
                                    turbo_stream_flash(notice: notice) ]) if inline?("discussion")

      redirect_back fallback_location: portal_tasks_path(task: task.id), notice: notice
    else
      return refuse_in_place(note.errors.full_messages.to_sentence) if inline?("discussion")

      redirect_back fallback_location: portal_tasks_path(task: task.id), alert: note.errors.full_messages.to_sentence
    end
  end
end
