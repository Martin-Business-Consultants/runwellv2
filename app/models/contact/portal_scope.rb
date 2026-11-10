# What one contact sees in the portal. Everything shared with their client, unless they're limited
# (portal_limited) to some of its work: then only those pieces of work, the tasks and files on
# them, and anything they asked for themselves. Every portal page, tool and email reads through
# here (portal_works, portal_tasks, portal_documents, sees?), never the client's records directly,
# so a limit holds everywhere at once.
module Contact::PortalScope
  extend ActiveSupport::Concern

  included do
    has_many :contact_works, foreign_key: :user_id, inverse_of: :contact, dependent: :delete_all
    has_many :limited_works, through: :contact_works, source: :work
  end

  def portal_works = portal_limited? ? client.works.where(id: contact_works.select(:work_id)) : client.works

  # The tasks shared with their client that this contact sees: all of them, or those on their
  # work plus what they asked for.
  def portal_tasks
    shared = Task.client_visible.where(client_id: client_id)
    portal_limited? ? shared.where(work_id: contact_works.select(:work_id)).or(shared.where(contact_id: id)) : shared
  end

  # The files shared with their client that this contact sees, newest first. Limited, that leaves
  # out files on the client itself.
  def portal_documents
    return client.client_documents unless portal_limited?

    works = contact_works.select(:work_id)
    Document.client_visible.where(documentable_type: "Work", documentable_id: works)
      .or(Document.client_visible.where(documentable_type: "ScopeItem", documentable_id: ScopeItem.where(work_id: works).select(:id)))
      .or(Document.client_visible.where(documentable_type: "Task", documentable_id: portal_tasks.select(:id)))
      .recent.includes(:documentable, file_attachment: :blob)
  end

  # Whether this contact sees a record in the portal: a piece of work, one of its sections, a
  # shared task, a shared file, or a note on any of them.
  def sees?(record)
    case record
    when Work then portal_works.exists?(record.id)
    when ScopeItem then portal_works.exists?(record.work_id)
    when Task then portal_tasks.exists?(record.id)
    when Document then portal_documents.exists?(record.id)
    when Note then sees?(record.subject)
    else false
    end
  end

  # What they see, in words, for their page and the history.
  def portal_scope_label = portal_limited? ? (limited_works.map(&:title).to_sentence.presence || "nothing yet") : "everything shared"

  # Limits them to these pieces of their client's work, or (limited: false) lets them see
  # everything shared again. The works chosen are kept either way.
  def set_portal_scope!(limited:, works: nil)
    transaction do
      self.limited_works = client.works.where(id: Array(works).map { it.respond_to?(:id) ? it.id : it }) unless works.nil?
      update!(portal_limited: limited)
      record_event!("contact.portal_scope", payload: { limited: portal_limited?, works: (limited_works.map(&:ref) if portal_limited?) }.compact)
    end
  end
end
