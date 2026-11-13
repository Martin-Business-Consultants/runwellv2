# Peeking: a client, a piece of work or a contact opened in the side panel over the page you're on
# (?peek=Work:12), as a task opens there (?task=42). The link's href stays the record's own page,
# for a new tab or a modifier click; built here, in Ruby, so its data attributes stay attributes.
#
# A link that opens a sheet is followed by a small arrow up and to the right (page_link_to): the
# record's own page, for when the sheet isn't enough. Text links get it by themselves; a link
# given as a block (a whole card or row, an icon button) doesn't, since a link can't hold another
# (open: false leaves it off a text link too, where a second link to the same record sits beside).
module PeekHelper
  def peek_link_to(record, content = nil, data: {}, open: true, **options, &block)
    action = [ data[:action], "side-panel#open" ].compact.join(" ")
    data = data.merge(turbo_frame: data[:turbo_frame] || "_top", action: action, side_panel_peek_param: QuickAction.value_for(record),
      side_panel_title_param: peek_title(record), turbo_prefetch: false)
    path = record.is_a?(Contact) ? edit_contact_path(record) : polymorphic_path(record)
    return link_to(path, data: data, **options, &block) if block

    with_page_link(link_to(content, path, data: data, **options), path, peek_title(record), open)
  end

  # The arrow to a record's own page: a full visit, never the sheet.
  def page_link_to(path, title)
    link_to(icon_tag("arrow-up-right"), path, class: "page-link", title: "Open #{title}", aria: { label: "Open #{title}" }, data: { turbo_frame: "_top" })
  end

  # A sheet link with its page link after it, kept together on a line.
  def with_page_link(link, path, title, open = true)
    open ? tag.span(safe_join([ link, page_link_to(path, title) ]), class: "sheet-link") : link
  end

  def peek_title(record) = record.is_a?(Work) ? record.title : record.name
end
