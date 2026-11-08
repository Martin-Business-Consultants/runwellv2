json.summary "#{@layout.kind}: #{@layout.main.size} in the working column, #{@layout.aside.size} in the sidebar, #{@layout.hidden.size} hidden"
json.kind @layout.kind
RecordLayout::ZONES.each do |zone|
  json.set! zone, @layout.public_send(zone) do |key|
    json.key key
    json.name layout_field_label(@layout, key)
    json.required @layout.required?(key)
  end
end
