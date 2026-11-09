class DocumentsController < ApplicationController
  include SubjectScoped
  before_action :set_subject, only: :create
  allow_staff
  agent_tool :add_document, on: :create, title: "Add a document to a record",
    description: "record: \"Type:id\" for a Client, Work, ScopeItem or Task. Files start internal; set_document_visibility shows one to the client.",
    params: { record: "string!", document: { files: "file!" } }
  agent_tool :set_document_visibility, on: :update, title: "Show or hide a document in the client’s portal",
    params: { document: { client_visible: "boolean!" } }, confirm: "Making it visible shows the file to the client in their portal."
  agent_tool :delete_document, on: :destroy, title: "Delete a document"

  def create
    subject = @subject

    files = Array(params.dig(:document, :files)).compact_blank
    documents = files.map { |file| subject.documents.new(file: file, uploaded_by: current_user) }
    if (refused = documents.find(&:invalid?))
      return redirect_back fallback_location: root_path, alert: "#{refused.filename} #{refused.errors[:file].to_sentence}."
    end
    documents.each(&:save!)

    if documents.any?
      subject.record_event!("document.added", payload: { files: documents.map { it.filename.to_s } }) if subject.respond_to?(:record_event!)
      redirect_back fallback_location: root_path, notice: "#{helpers.pluralize(documents.size, "file")} added."
    else
      redirect_back fallback_location: root_path, alert: "Choose a file to upload."
    end
  end

  def update
    document = Document.find(params[:id])
    # A plugin's rule may refuse sharing it (a file in a folder kept from the client): said in words.
    unless document.update(client_visible: params.dig(:document, :client_visible) == "1")
      alert = document.errors.full_messages.to_sentence
      return render(turbo_stream: [ turbo_stream_flash(alert: alert), turbo_stream.refresh(request_id: nil) ]) if request.format.turbo_stream?

      return redirect_back(fallback_location: root_path, alert: alert)
    end
    notice = document.client_visible? ? "The client can see #{document.filename}." : "#{document.filename} is internal."
    # The switch already shows the change: the notice is all there is to answer.
    return render(turbo_stream: turbo_stream_flash(notice: notice)) if request.format.turbo_stream?

    redirect_back fallback_location: root_path, notice: notice
  end

  def destroy
    document = Document.find(params[:id])
    return deny_access unless document.deletable_by?(current_user)

    document.destroy!
    notice = "#{document.filename} removed."
    if request.format.turbo_stream?
      render turbo_stream: [ turbo_stream.remove(helpers.dom_id(document, :row)), turbo_stream_flash(notice: notice) ]
    else
      redirect_back fallback_location: root_path, notice: notice
    end
  end
end
