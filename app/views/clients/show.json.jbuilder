json.summary "#{@client.name} (#{@client.status})"
json.client do
  json.partial! "clients/client", client: @client
  json.contacts @client.contacts.active.ordered, partial: "contacts/contact", as: :contact
  json.engagements @client.engagements.ordered.includes(:client, :custom_values, agreement_versions: :approval), partial: "engagements/engagement", as: :engagement
  json.open_commitments @client.commitments.open.ordered, partial: "commitments/commitment", as: :commitment
  json.notes @client.notes.recent.includes(:author).limit(20), partial: "notes/note", as: :note
  json.documents @client.documents.recent, partial: "documents/document", as: :document
end
