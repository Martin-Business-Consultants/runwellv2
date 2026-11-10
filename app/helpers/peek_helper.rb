# Peeking: a client, a piece of work or a contact opened in the side panel over the page you're on
# (?peek=Work:12), as a task opens there (?task=42). The link's href stays the record's own page,
# for a new tab or a modifier click; built here, in Ruby, so its data attributes stay attributes.
module PeekHelper
  def peek_link_to(record, content = nil, data: {}, **options, &block)
    action = [ data[:action], "side-panel#open" ].compact.join(" ")
    data = data.merge(turbo_frame: data[:turbo_frame] || "_top", action: action, side_panel_peek_param: QuickAction.value_for(record),
      side_panel_title_param: peek_title(record), turbo_prefetch: false)
    path = record.is_a?(Contact) ? edit_contact_path(record) : polymorphic_path(record)
    block ? link_to(path, data: data, **options, &block) : link_to(content, path, data: data, **options)
  end

  def peek_title(record) = record.is_a?(Work) ? record.title : record.name
end
