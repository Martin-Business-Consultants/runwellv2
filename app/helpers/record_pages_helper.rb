# A record's page (clients, work, contacts, people, tasks, sections), on runeui: its header is
# ui :page_header (record_header), its cards ui :card (record_card), its tabs ui :tabs as links
# (layouts/shared/record_tabs, RecordTabsHelper).
module RecordPagesHelper
  # A card on a record's page or in its sidebar: its title (a heading) and the line under it, an
  # action at the head's end (a filter, a switch), the block stacked as its content, and a footer
  # (the add button under its list). runeui's ui :card; record-card is Runwell's spacing inside.
  # A title that's already markup (template mode's renamable heading) goes in as it is.
  def record_card(heading = nil, title: heading, hint: nil, action: nil, footer: nil, css: nil, **attrs, &block)
    title = tag.h2(title, class: "record-card__title") if title.present? && !title.html_safe?
    ui :card, title: title.presence, description: hint.presence,
      action: action.presence, footer: footer.presence, class: [ "record-card", css ].compact,
      content: (capture(&block).presence if block), **attrs
  end

  # A record page's header row (ui :page_header): what the block draws (the title, changed in
  # place, and the lines under it) and the page's actions at the end, the arrange button and the
  # sidebar toggle (]) last.
  def record_header(id:, actions: nil, arrange: true, &block)
    buttons = safe_join([ actions, (render("record_fields/arrange_button") if arrange), render("layouts/shared/sidebar_toggle") ].compact)
    ui :page_header, id: id, class: "record-header", actions: buttons, content: capture(&block)
  end

  # The button heading a record's History card (events/timeline): its name and how many changes it
  # lists, with the chevron that turns as it opens (ui :collapsible's trigger).
  def timeline_trigger(count)
    tag.button(type: "button", class: "record-timeline__trigger", data: { slot: "collapsible-trigger" }) do
      safe_join([
        tag.span(safe_join([ tag.span("History", class: "record-timeline__title"),
                             tag.span("The last #{pluralize count, "change"}, newest first", class: "record-timeline__hint") ]), class: "record-timeline__head"),
        icon_tag("chevron", class: "record-timeline__chevron")
      ])
    end
  end
end
