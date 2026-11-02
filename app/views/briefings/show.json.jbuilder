sections = @briefing.sections
json.summary sections.any? ? sections.map { "#{it.count} #{it.title.downcase}" }.to_sentence : "Nothing needs a person right now."
json.sections sections do |section|
  json.key section.key
  json.title section.title
  json.group section.group
  json.count section.count
  json.items section.items do |item|
    case item
    when Todo
      json.merge! agent_ref(item)
      json.partial! "todos/todo", todo: item
    when Notification
      ref, name = notification_target_label(item.notifiable_target)
      json.mention_by item.creator.display_name
      json.on [ ref, name ].compact.join(" ")
      json.at item.created_at
      json.url notification_url(item)
    else
      json.merge! agent_ref(item)
    end
  end
end
