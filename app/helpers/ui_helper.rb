# Runwell's own builders over rune_ui (the gem's helpers: button_link, button_classes, badge,
# avatar, menu, popover_menu, dialog, tabs…; see ../rune_ui/README.md). The styleguide at /ui
# (development) shows the components.
module UiHelper
  # Runwell's status tones (ApplicationHelper::STATUS_TONES) as rune_ui's badge tones.
  STATUS_BADGES = { "positive" => :ok, "negative" => :danger, "waiting" => :attention, "progress" => :accent, "neutral" => :neutral }.freeze

  # A status in its tone: ui_status_badge("overdue").
  def ui_status_badge(label, highlight: false, **options)
    badge(label, tone: STATUS_BADGES.fetch(status_tone(label, highlight: highlight)), **options)
  end

  # Data table (ui/_data_table): one column of it. key names the column (its cells carry
  # data-column="key", so the Columns menu can hide them); sort: the TableSorting key that
  # orders by it; width: a COLUMN_SHAPES shape or [characters, header] for ui_data_table_colgroup (the
  # column that isn't hideable takes the leftover width instead);
  # hideable: false keeps it out of the Columns menu (the name column).
  # grow: true names the column that takes the leftover width, where it isn't the one that can't be
  # hidden.
  UiColumn = Data.define(:key, :label, :sort, :width, :align, :hideable, :header_class, :grow)

  def ui_column(key, label = key.to_s.humanize, sort: nil, width: :text, align: nil, hideable: true, header_class: nil, grow: nil)
    width = [ width, label ] if width.is_a?(Numeric) || width.nil?
    UiColumn.new(key: key.to_s, label: label, sort: sort, width: width, align: align, hideable: hideable, header_class: header_class, grow: grow)
  end

  def ui_data_table_th(column)
    classes = class_names(column.header_class, "data-table__number" => column.align == :end, "data-table__center" => column.align == :center)
    if column.sort
      sortable_th(column.label, column.sort, class: classes.presence, data: { column: column.key })
    else
      tag.th(column.label, class: classes.presence, data: { column: column.key })
    end
  end

  # The data table's colgroup, rune_ui's column convention (data.css): the column that identifies
  # the row (hideable: false, else the first) takes the leftover width; every other column is as
  # wide as its content, from the data (column_widths' longest value, never narrower than its
  # header) or its shape (COLUMN_SHAPES), so the widths hold still whatever the sort or page, and
  # narrow facts sit together one gap apart. Long text in a fitted column is capped (it truncates).
  # Each data column's <col> carries its key, so hiding a column (the Columns menu) hides its width.
  FIT_CAP = 28

  def ui_data_table_colgroup(columns, selectable:, actions:)
    grow = columns.find(&:grow) || columns.find { !it.hideable } || columns.first
    entries = [ *([ [ nil, :select, false ] ] if selectable), *columns.map { [ it.key, it.width, it.equal?(grow) ] }, *([ [ nil, :actions, false ] ] if actions) ]

    tag.colgroup do
      safe_join(entries.map do |key, width, growing|
        tag.col(class: growing ? "data-table__col--grow" : "data-table__col--w#{column_characters(width)}", data: { column: key })
      end)
    end
  end

  # A fitted column's width in characters: its shape's, or its longest value's (capped), and never
  # narrower than its header.
  def column_characters(width)
    return TableSortingHelper::COLUMN_SHAPES.fetch(width) if width.is_a?(Symbol)

    length, header = width
    [ [ length.to_i, FIT_CAP ].min, header.to_s.length + 2 ].max.clamp(3, 48)
  end
end
