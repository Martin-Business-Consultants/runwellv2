# Tells a client's people about files the team shared with them: one email for those shared
# together. Each shared file queues this a few minutes on; only the latest one's run sends, listing
# everything shared in the stretch before it, so ten files dropped at once are one email.
class SharedDocumentsJob < ApplicationJob
  QUIET = 5.minutes
  STRETCH = 15.minutes

  def perform(document)
    client = document.client
    return unless client && document.client_visible?

    shared = client.client_documents.where(updated_at: STRETCH.ago..).reorder(updated_at: :desc, id: :desc).to_a.reject { it.uploaded_by&.client? }
    return unless shared.first == document

    Notice.contacts("document", client: client, record: document, usual: Notice.reachable_contacts(client)).each do |contact|
      # Only the files this person sees in the portal (Contact::PortalScope).
      theirs = shared.select { contact.sees?(it) }
      PortalMailer.with(documents: theirs, contact: contact).documents.deliver_later if theirs.any?
    end
  end
end
