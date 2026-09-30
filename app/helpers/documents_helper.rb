module DocumentsHelper
  # What clicking a document does: images open in a preview dialog, PDFs in a new tab, and
  # anything else downloads. SVG stays a download, since Active Storage serves it as binary.
  def document_preview_kind(document)
    case document.content_type.to_s
    when %r{\Aimage/(png|jpeg|gif|webp|avif)\z} then :image
    when "application/pdf" then :tab
    else :download
    end
  end
end
