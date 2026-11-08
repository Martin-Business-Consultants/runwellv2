json.summary "#{pluralize @documents.size, "document"} shared with you"
json.documents @documents do |document|
  json.filename document.filename.to_s
  json.byte_size document.byte_size
  json.shared_on document.created_at.to_date
  json.on portal_document_place(document)
  json.url rails_blob_url(document.file, disposition: "attachment")
end
