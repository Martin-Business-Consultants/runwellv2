class DocumentsController < ApplicationController
  allow_staff
  agent_tool :add_document, on: :create, title: "Add a document to a record",
    description: "record: \"Type:id\" for a Client, Engagement, ScopeItem, Todo or Request. Files start internal; set_document_visibility shows one to the client.",
    params: { record: "string!", document: { files: "file!" } }
  agent_tool :set_document_visibility, on: :update, title: "Show or hide a document in the client’s portal",
    params: { document: { client_visible: "boolean!" } }, confirm: "Making it visible shows the file to the client in their portal."
  agent_tool :delete_document, on: :destroy, title: "Delete a document"

  SUBJECTS = %w[Client Engagement ScopeItem Todo Request].freeze

  def create
    subject = find_subject or return redirect_back(fallback_location: root_path, alert: "Choose where this goes.")

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
    document.update!(client_visible: params.dig(:document, :client_visible) == "1")
    redirect_back fallback_location: root_path, notice: document.client_visible? ? "The client can see #{document.filename}." : "#{document.filename} is internal."
  end

  def destroy
    document = Document.find(params[:id])
    return deny_access unless document.deletable_by?(current_user)

    document.destroy!
    redirect_back fallback_location: root_path, notice: "#{document.filename} removed."
  end

  private
    # The record picked in the quick action tray ("Client:12").
    def find_subject
      QuickAction.locate(params[:record], SUBJECTS) if params[:record].present?
    end
end
