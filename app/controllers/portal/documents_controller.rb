# Every document shared with the client, in one place (the portal's Documents): on their work, its
# sections, the tasks they can see, and the client itself, newest first, found by name (?q=).
class Portal::DocumentsController < Portal::BaseController
  agent_tool :portal_documents, on: :index, title: "Documents shared with you",
    description: "Every file shared with you, newest first: its name, size, date, and what it's on. q: words to find in their names.",
    params: { q: "string" }

  # A plugin's page standing in for this one (Runwell::Plugins.portal_nav replaces: :documents) is
  # where a person goes instead; an agent still gets the list.
  def index
    if request.format.html? && (replacement = Runwell::Plugins.portal_replacement(:documents)) && (url = helpers.instance_exec(&replacement.last))
      return redirect_to(url)
    end

    documents = current_contact.portal_documents
    if params[:q].present?
      named = ActiveStorage::Attachment.where(record_type: "Document", name: "file").joins(:blob)
        .where("lower(active_storage_blobs.filename) LIKE ?", "%#{Document.sanitize_sql_like(params[:q].to_s.downcase.strip)}%")
      documents = documents.where(id: named.select(:record_id))
    end
    @documents = portal_page(documents).to_a
    # A section's file names its work beside it: read those once.
    ActiveRecord::Associations::Preloader.new(records: @documents.filter_map { it.documentable if it.documentable_type == "ScopeItem" }, associations: :work).call
  end
end
