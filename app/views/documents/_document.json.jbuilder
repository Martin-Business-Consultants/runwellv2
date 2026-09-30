json.merge! agent_ref(document)
json.filename document.filename.to_s
json.extract! document, :byte_size, :content_type, :client_visible, :created_at
json.uploaded_by agent_user(document.uploaded_by)
json.download_url request.base_url + rails_blob_path(document.file, disposition: :attachment)
