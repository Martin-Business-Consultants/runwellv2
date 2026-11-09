json.summary "#{@layout.sections.size} #{@layout.sections.size == 1 ? "section" : "sections"}: " +
  @layout.sections.map { |section| "#{section["label"].presence || "(no heading)"} (#{section["items"].map { nav_item_name(it).first }.join(", ")})" }.join("; ") +
  (@layout.hidden.any? ? "; hidden: #{@layout.hidden.map { nav_item_name(it).first }.join(", ")}." : ".")
json.sections @layout.sections do |section|
  json.label section["label"]
  json.items section["items"] do |item|
    json.key item
    json.name nav_item_name(item).first
  end
end
json.hidden @layout.hidden do |item|
  json.key item
  json.name nav_item_name(item).first
end
json.customized @layout.customized?
