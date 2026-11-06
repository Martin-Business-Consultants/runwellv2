# Runwell UI: Runwell's own builders over nobuild_ui (the gem's NobuildUi::Helper has ui_button,
# ui_link_button, ui_button_classes, ui_badge, ui_kbd, ui_avatar, ui_dropdown and the menu
# items). The styleguide at /ui (development) shows every component.
module UiHelper
  STATUS_BADGES = { "positive" => :positive, "negative" => :negative, "waiting" => :warning, "progress" => :info, "neutral" => :neutral }.freeze

  # A status in its tone: ui_status_badge("overdue").
  def ui_status_badge(label, highlight: false, **options)
    ui_badge(label, STATUS_BADGES.fetch(status_tone(label, highlight: highlight)), **options)
  end

  # Data table (ui/_data_table): one column of it. key names the column (its cells carry
  # data-column="key", so the Columns menu can hide them); sort: the TableSorting key that
  # orders by it; width: a COLUMN_SHAPES shape or [characters, header] for table_colgroup;
  # hideable: false keeps it out of the Columns menu (the name column).
  UiColumn = Data.define(:key, :label, :sort, :width, :align, :hideable, :header_class)

  def ui_column(key, label = key.to_s.humanize, sort: nil, width: :text, align: nil, hideable: true, header_class: nil)
    width = [ width, label ] if width.is_a?(Numeric) || width.nil?
    UiColumn.new(key: key.to_s, label: label, sort: sort, width: width, align: align, hideable: hideable, header_class: header_class)
  end

  def ui_data_table_th(column)
    classes = class_names(column.header_class, "data-table__number" => column.align == :end, "txt-align-center" => column.align == :center)
    if column.sort
      sortable_th(column.label, column.sort, class: classes.presence, data: { column: column.key })
    else
      tag.th(column.label, class: classes.presence, data: { column: column.key })
    end
  end

  # The data table's colgroup, as table_colgroup's: the select and actions columns around the
  # data columns' shares. Each data column's <col> carries its key, so hiding a column (the
  # Columns menu) hides its width too.
  def ui_data_table_colgroup(columns, selectable:, actions:)
    entries = [ *([ [ nil, :select ] ] if selectable), *columns.map { [ it.key, it.width ] }, *([ [ nil, :actions ] ] if actions) ]
    characters = entries.map do |_key, width|
      next TableSortingHelper::COLUMN_SHAPES.fetch(width) if width.is_a?(Symbol)

      length, header = width
      [ length.to_i, header.to_s.length + 4 ].max
    end
    total = characters.sum.to_f

    tag.colgroup do
      safe_join(entries.zip(characters).map do |(key, _width), chars|
        tag.col(class: "data-table__col--p#{(chars / total * 100).round.clamp(1, 100)}", data: { column: key })
      end)
    end
  end
end
