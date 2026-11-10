# Files a client's person sends from the portal, with a request or a reply: each becomes a document
# on the task, theirs (uploaded_by) and shown to the client, since it is the client's own. One that
# can't be kept (over the size limit) is named in what comes back.
module PortalUploads
  extend ActiveSupport::Concern

  private
    # Returns the names of any that were refused.
    def attach_portal_files(task, files)
      Array(files).select { it.respond_to?(:original_filename) }.filter_map do |file|
        document = task.documents.new(file: file, uploaded_by: current_contact, client_visible: true)
        "#{file.original_filename} (#{document.errors.full_messages.to_sentence.downcase})" unless document.save
      end
    end

    def refused_files_notice(refused) = refused.any? ? " Not kept: #{refused.to_sentence}." : ""
end
