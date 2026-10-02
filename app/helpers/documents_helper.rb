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

  # The dashed box files are dropped on (documents/_section, the tray's Document), for the form
  # the upload controller is on. Each file goes straight to storage with its progress shown here,
  # then the form posts them. A helper, since partials can't render inside form_with.
  def document_drop_target(form, class_name)
    tag.label class: "btn input--upload #{class_name}" do
      safe_join [
        icon_tag("attachment"),
        tag.span(data: { upload_target: "status" }) do
          safe_join [ "Drop files here or ", tag.span("choose…", class: "txt-link"), tag.span(" · up to #{number_to_human_size(Document::MAX_SIZE)} each", class: "txt-subtle") ]
        end,
        tag.progress(max: 100, value: 0, hidden: true, data: { upload_target: "progress" }),
        form.file_field(:files, name: "document[files][]", multiple: true, id: nil, aria: { label: "Add documents" },
          data: { upload_target: "input", action: "change->upload#start" })
      ]
    end
  end

  def document_upload_data
    { controller: "upload", upload_url_value: rails_direct_uploads_url, upload_max_size_value: Document::MAX_SIZE, turbo_frame: "_top" }
  end
end
