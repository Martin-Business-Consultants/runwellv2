# Runwell UI: builders for the shadcn/ui port (app/assets/stylesheets/ui). The CSS classes are
# the components; these only spell them, the way shadcn's buttonVariants() and badgeVariants()
# do, so a view writes ui_button("Save") or link_to(…, class: ui_button_classes(:outline)).
# The styleguide at /ui (development) shows every component.
module UiHelper
  BUTTON_VARIANTS = %i[default destructive outline secondary ghost link].freeze
  BUTTON_SIZES = %i[default sm lg icon icon_sm icon_lg].freeze
  BADGE_VARIANTS = %i[default secondary destructive outline positive warning info negative neutral count].freeze

  # Class names for a button: ui_button_classes(:outline, size: :sm, class: "x").
  def ui_button_classes(variant = :default, size: :default, full_width: false, **options)
    variant = variant.to_sym
    size = size.to_sym
    raise ArgumentError, "unknown button variant #{variant}" unless BUTTON_VARIANTS.include?(variant)
    raise ArgumentError, "unknown button size #{size}" unless BUTTON_SIZES.include?(size)

    class_names("ui-button",
      "ui-button--#{variant}" => variant != :default,
      "ui-button--#{size.to_s.dasherize}" => size != :default,
      "ui-button--block" => full_width,
      options[:class] => options[:class].present?)
  end

  # A <button>: ui_button("Save"), ui_button(variant: :outline) { … }, or with an icon:
  # ui_button("Add", icon: "add"). type defaults to "button"; pass type: "submit" in a form.
  def ui_button(text = nil, variant: :default, size: :default, icon: nil, full_width: false, **options, &block)
    options[:type] ||= "button"
    options[:class] = ui_button_classes(variant, size: size, full_width: full_width, class: options[:class])
    tag.button(**options) { ui_button_content(text, icon, &block) }
  end

  # A link drawn as a button: ui_link_button("New client", new_client_path, variant: :outline).
  def ui_link_button(text, url, variant: :default, size: :default, icon: nil, full_width: false, **options)
    options[:class] = ui_button_classes(variant, size: size, full_width: full_width, class: options[:class])
    link_to(url, **options) { ui_button_content(text, icon) }
  end

  # A badge: ui_badge("Active", :positive), or a status in its tone: ui_status_badge("overdue").
  def ui_badge(text, variant = :default, **options)
    variant = variant.to_sym
    raise ArgumentError, "unknown badge variant #{variant}" unless BADGE_VARIANTS.include?(variant)

    tag.span text, **options, class: class_names("ui-badge", "ui-badge--#{variant}" => variant != :default, options[:class] => options[:class].present?)
  end

  STATUS_BADGES = { "positive" => :positive, "negative" => :negative, "waiting" => :warning, "progress" => :info, "neutral" => :neutral }.freeze

  def ui_status_badge(label, highlight: false, **options)
    ui_badge(label, STATUS_BADGES.fetch(status_tone(label, highlight: highlight)), **options)
  end

  def ui_kbd(*keys)
    return tag.kbd(keys.first, class: "ui-kbd") if keys.one?

    tag.span(safe_join(keys.map { tag.kbd(it, class: "ui-kbd") }), class: "ui-kbd-group")
  end

  # Initials in a circle, or the image when there is one: ui_avatar("Ted Martin", size: :sm).
  def ui_avatar(name, image: nil, size: nil, **options)
    classes = class_names("ui-avatar", "ui-avatar--#{size}" => size, options.delete(:class) => true)
    tag.span(class: classes, title: name, **options) do
      if image
        image_tag(image, alt: name)
      else
        name.to_s.split.first(2).map { it[0] }.join.upcase
      end
    end
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

  private
    def ui_button_content(text, icon, &block)
      parts = []
      parts << icon_tag(icon) if icon
      parts << (block ? capture(&block) : text)
      safe_join(parts.compact)
    end
end
