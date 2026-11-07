class NotesController < ApplicationController
  allow_staff
  agent_tool :add_note, on: :create, title: "Add a note to a record",
    description: "record: \"Type:id\" for a Client, Work, ScopeItem or Task (e.g. \"Client:12\"). @mention someone by writing their name; they are notified.",
    params: { record: "string!", note: { body: "text!", kind: Note::KINDS, source: "string" } }
  agent_tool :delete_note, on: :destroy, title: "Delete a note",
    description: "Only its author (or the author's person, for a note their agent wrote) or someone who may delete records."

  SUBJECTS = %w[Client Work ScopeItem Task].freeze

  def create
    subject = find_subject or return redirect_back(fallback_location: root_path, alert: "Choose where this goes.")
    note = subject.notes.new(params.expect(note: %i[body kind occurred_at source]).merge(author: current_user))
    note.source = note.source.presence || Current.source || "app"
    if note.save
      subject.record_event!("note.added", payload: { kind: note.kind }) if subject.respond_to?(:record_event!)
      # From the composer on the record's own page: just its notes and the notice, no reload.
      if params[:inline] == "notes" && request.format.turbo_stream?
        flash.now[:notice] = "Note added."
        render turbo_stream: [ turbo_stream.replace(helpers.dom_id(subject, :notes_feed), partial: "notes/feed", locals: { subject: subject }),
                               turbo_stream.replace("flash", partial: "layouts/shared/flash") ]
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
    subject.record_event!("note.deleted", payload: { kind: note.kind }) if subject.respond_to?(:record_event!)
    redirect_back fallback_location: subject || root_path, notice: "Note deleted."
  end

  private
    # The record picked in the quick action tray ("Client:12").
    def find_subject
      QuickAction.locate(params[:record], SUBJECTS) if params[:record].present?
    end
end
