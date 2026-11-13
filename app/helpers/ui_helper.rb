# Runwell's own builders over runeui (ui :table, ui :badge…; ../runeui/README.md): statuses in
# their tones and an index's table. The styleguide at /ui (development) shows the components.
module UiHelper
  # Runwell's status tones (ApplicationHelper::STATUS_TONES) as runeui's badge variants.
  STATUS_BADGES = { "positive" => :success, "negative" => :destructive, "waiting" => :warning, "progress" => :info, "neutral" => :secondary }.freeze

  # A status in its tone (ui :badge): ui_status_badge("overdue"). A snake_case status shows
  # humanized; other text as it is.
  def ui_status_badge(label, highlight: false, **options)
    text = label.is_a?(Symbol) || label.to_s.match?(/\A[a-z_]+\z/) ? label.to_s.humanize : label.to_s
    ui :badge, content: text, variant: STATUS_BADGES.fetch(status_tone(label, highlight: highlight)), **options
  end

  # An index's table (layouts/shared/_list_table, on runeui's ui :table): one column of it. key
  # names the column (its cells carry data-column="key", so the Columns menu can hide them);
  # sort: the TableSorting key that orders by it; align: :end for numbers, :center; hideable: false
  # keeps it out of the Columns menu (the column that names the row). That column takes the width
  # the others leave and cuts a long name short (data-grow on its cells); grow: true names it where
  # it isn't the one that can't be hidden. Every other column is as wide as what it holds.
  UiColumn = Data.define(:key, :label, :sort, :align, :hideable, :grow)

  def ui_column(key, label = key.to_s.humanize, sort: nil, align: nil, hideable: true, grow: nil)
    UiColumn.new(key: key.to_s, label: label, sort: sort, align: align, hideable: hideable, grow: grow)
  end

  # The column of a list that takes the leftover width.
  def list_table_grow(columns)
    columns.find(&:grow) || columns.find { !it.hideable } || columns.first
  end

  # A column's header: a link that sorts by it (ui :sort_header, which writes the sort and
  # direction params TableSorting reads, keeps the page's others and drops the page), or its name.
  def list_table_th(column, grow: false)
    data = { column: column.key, grow: (true if grow) }.compact
    if column.sort
      current, direction = current_sort
      ui :sort_header, label: column.label, key: column.sort, sort: current, direction: direction, align: column.align, data: data
    else
      ui_tag :th, { data: data.merge(align: column.align&.to_s) }, {}, column.label
    end
  end

  # Under a list: which rows are showing, and the pages (ui :pagination, over geared_pagination's
  # page). Nothing for one page.
  def table_pagination(page)
    count = page.recordset.page_count
    return if count <= 1

    per_page = page.recordset.ratios[page.number]
    first_row = (page.number - 1) * per_page + 1
    last_row = [ page.number * per_page, page.recordset.records_count ].min
    tag.div(class: "list-pagination") do
      safe_join([ tag.span("#{first_row}–#{last_row} of #{page.recordset.records_count}", class: "list-pagination__summary"),
        ui(:pagination, page: page.number, pages: count, label: "Pages") ])
    end
  end

  # New: an index's primary action (ui :button), with the key that presses it. On a phone, just
  # the icon. frame: the Turbo Frame its form opens in ("modal").
  def new_link(text, path, icon: "add", key: "n", frame: nil)
    ui :button, href: path, class: "new-link", data: { keys: key, turbo_frame: frame },
      content: safe_join([ icon_tag(icon), tag.span(text, class: "new-link__text"), tag.kbd(key.upcase, class: "new-link__key hide-on-touch") ])
  end

  # An index's views as links (ui :toggle_group): each keeps the page's other params; v goes to
  # the one after the current, g b to the board. views: [key, label, icon] each.
  def view_toggle(current, views)
    following = views[(views.index { |key, _label, _icon| key == current } || -1) + 1]&.first || views.first.first
    options = views.map do |key, label, icon|
      keys = [ ("v" if key == following), ("g b" if key == "board") ].compact.join(", ").presence
      [ label, key, { icon: icon_tag(icon), title: label, href: url_for(request.query_parameters.merge("view" => key)), data: { keys: keys }.compact } ]
    end
    ui :toggle_group, value: current, variant: :outline, size: :sm, label: "View", class: "view-toggle", options: options
  end
end
