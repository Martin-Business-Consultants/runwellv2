class NotesController < ApplicationController
  include SubjectScoped
  before_action :set_subject, only: :create
  allow_staff
  agent_tool :add_note, on: :create, title: "Add a note to a record",
    description: "record: \"Type:id\" for a Client, Work, ScopeItem or Task (e.g. \"Client:12\"). @mention someone by writing their name; they are notified.",
    params: { record: "string!", note: { body: "text!", kind: Note::KINDS, source: "string" } }
  agent_tool :delete_note, on: :destroy, title: "Delete a note",
    description: "Only its author (or the author's person, for a note their agent wrote) or someone who may delete records."

  def create
    subject = @subject
    note = subject.notes.new(params.expect(note: %i[body kind occurred_at source]).merge(author: current_user))
    note.source = note.source.presence || Current.source || "app"
    if note.save
      # From the composer on the record's own page: just its notes and the notice, no reload.
      if params[:inline] == "notes" && request.format.turbo_stream?
        render turbo_stream: [ turbo_stream.replace(helpers.dom_id(subject, :notes_feed), partial: "notes/feed", locals: { subject: subject }),
                               turbo_stream_flash(notice: "Note added.") ]
      else
        redirect_back fallback_location: subject, notice: "Note added."
      end
    else
      # From the composer: say why where you are, keeping what was typed.
      return refuse_in_place(note.errors.full_messages.to_sentence) if params[:inline] == "notes" && request.format.turbo_stream?

      redirect_back fallback_location: subject, alert: note.errors.full_messages.to_sentence
    end
  end

  def destroy
    note = Note.find(params[:id])
    return redirect_back(fallback_location: root_path, alert: "Only its author can delete this note.") unless note.deletable_by?(current_user)

    subject = note.subject
    note.destroy!
    redirect_back fallback_location: subject || root_path, notice: "Note deleted."
  end
end
