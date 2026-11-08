# A task's discussion with the client: a note staff send to the client (Send to client in the
# task's notes), shared on the task in the portal, where the client can reply. Internal notes stay
# internal; this is the one way a note reaches the client.
class Tasks::DiscussionsController < ApplicationController
  allow_staff
  agent_tool :reply_to_client, on: :create, title: "Write to the client on a task",
    description: "A note on the task the client sees in their portal, under its discussion, and can answer there. Only on a task shown to the client. Keep it to what they should read; use add_note for anything internal.",
    params: { note: { body: "text!" } }, confirm: "The client reads it in their portal, on the task."

  def create
    task = Task.find(params[:task_id])
    return redirect_back(fallback_location: task, alert: "The client can’t see this #{Setting.current.term(:task).downcase}: show it to them first.") unless task.client_visible? && task.client

    note = task.notes.new(body: params.expect(note: [ :body ])[:body], kind: "internal", client_visible: true,
      author: current_user, source: Current.source || "app")
    if note.save
      notice = "Sent to #{task.client.name}: it’s on the #{Setting.current.term(:task).downcase} in their portal."
      # From the composer: just the notes and the notice, as adding a note does.
      if params[:inline] == "notes" && request.format.turbo_stream?
        return render turbo_stream: [ turbo_stream.replace(helpers.dom_id(task, :notes_feed), partial: "notes/feed", locals: { subject: task }),
                                      turbo_stream_flash(notice: notice) ]
      end
      redirect_back fallback_location: task, notice: notice
    else
      redirect_back fallback_location: task, alert: note.errors.full_messages.to_sentence
    end
  end
end
