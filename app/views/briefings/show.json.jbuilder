busy = @sections
json.summary busy.any? ? busy.map { "#{it.count} #{it.title.downcase}" }.to_sentence : "Nothing needs a person right now."
json.sections busy do |section|
  json.key section.key
  json.title section.title
  json.count section.count
  json.items section.items do |item|
    json.merge! agent_ref(item)
    case item
    when Question then json.extract! item, :choices, :context
    when Todo then json.partial! "todos/todo", todo: item
    when Commitment then json.partial! "commitments/commitment", commitment: item
    when Request then json.partial! "requests/request", request_record: item
    when AgreementVersion then json.partial! "agreement_versions/agreement_version", agreement_version: item
    end
  end
end
