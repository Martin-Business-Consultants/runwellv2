json.summary "#{@request.subject} (#{@request.status})"
json.request do
  json.partial! "requests/request", request: @request
  json.extract! @request, :sender_name, :sender_email
  json.contact agent_ref(@request.contact)
  json.body agent_text(@request.body)
  json.notes @request.notes.recent.includes(:author), partial: "notes/note", as: :note
  json.documents @request.documents.recent, partial: "documents/document", as: :document
end
