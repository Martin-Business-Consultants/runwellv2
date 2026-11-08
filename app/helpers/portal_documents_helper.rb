# The portal's Documents: what each file is on, in the client's words, beside its size and date.
module PortalDocumentsHelper
  def portal_document_place(document)
    case (record = document.documentable)
    when Work then record.title
    when ScopeItem then "#{record.work.title}: #{record.description}"
    when Task then record.title
    end
  end

  def portal_document_meta(document)
    [ portal_document_place(document), number_to_human_size(document.byte_size), l(document.created_at.to_date, format: :long) ].compact.join(" · ")
  end
end
