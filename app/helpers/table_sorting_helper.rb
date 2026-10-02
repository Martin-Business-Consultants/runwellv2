# Index tables (TableSorting): headers that sort, and the pages under the table.
module TableSortingHelper
  # A column header that sorts the table by `key`: ascending first, then the other way. It keeps
  # the page's filters and view and goes back to the first page. The sorted column says so to
  # screen readers (aria-sort) and shows its direction.
  def sortable_th(label, key, **options)
    key = key.to_s
    current, direction = current_sort
    active = current == key
    next_direction = active && direction == "asc" ? "desc" : "asc"

    tag.th(**options, class: class_names("data-table__sortable", options[:class]),
      "aria-sort": (active ? (direction == "asc" ? "ascending" : "descending") : nil)) do
      link_to url_for(request.query_parameters.except("page").merge("sort" => key, "direction" => next_direction)),
        class: class_names("data-table__sort", "data-table__sort--active": active), data: { turbo_action: "replace" } do
        safe_join([ label, tag.span(class: class_names("data-table__sort-arrow", "data-table__sort-arrow--desc": active && direction == "desc"), "aria-hidden": true) ])
      end
    end
  end

  # How many characters a column of each fixed shape needs (its content never changes width).
  COLUMN_SHAPES = { avatar: 7, avatars: 10, date: 15, age: 14, status: 11, pill: 11, number: 14, button: 10, actions: 9, text: 16 }.freeze

  # The table's column widths, so they hold still whatever the sort or page (with
  # `table-layout: fixed`, data-table--fixed). One entry per column: [characters, header] for a
  # text column (from column_widths: its longest value, and never narrower than its header), or
  # a shape from COLUMN_SHAPES. Each column gets its share of the total as a percentage, so the
  # table always fits its page; the shares depend only on the data, never on the rows showing.
  def table_colgroup(*columns)
    characters = columns.map do |column|
      next COLUMN_SHAPES.fetch(column) if column.is_a?(Symbol)

      length, header = column
      [ length.to_i, header.to_s.length + 4 ].max
    end
    total = characters.sum.to_f

    tag.colgroup do
      safe_join(characters.map { tag.col(class: "data-table__col--p#{(it / total * 100).round.clamp(1, 100)}") })
    end
  end

  # Under a table: how many rows are showing, then Previous, the page numbers (the current one,
  # its neighbours, the first and the last, with gaps between) and Next. Nothing for one page.
  def table_pagination(page)
    count = page.recordset.page_count
    return if count <= 1

    per_page = page.recordset.ratios[page.number]
    first_row = (page.number - 1) * per_page + 1
    last_row = [ page.number * per_page, page.recordset.records_count ].min

    tag.nav class: "table-pagination", "aria-label": "Pages" do
      safe_join([
        tag.span("#{first_row}–#{last_row} of #{page.recordset.records_count}", class: "table-pagination__summary"),
        tag.div(class: "table-pagination__pages") do
          safe_join([
            table_page_link("Previous", page.number - 1, disabled: page.first?, rel: "prev"),
            *table_page_numbers(page.number, count).map { |number|
              number ? table_page_link(number.to_s, number, current: number == page.number) : tag.span("…", class: "table-pagination__gap")
            },
            table_page_link("Next", page.number + 1, disabled: page.last?, rel: "next")
          ])
        end
      ])
    end
  end

  private

  def table_page_numbers(current, count)
    shown = [ 1, count, current - 1, current, current + 1 ].select { it.between?(1, count) }.uniq.sort
    shown.each_with_object([]) do |number, list|
      list << nil if list.any? && number - list.last > 1
      list << number
    end
  end

  def table_page_link(label, number, disabled: false, current: false, rel: nil)
    classes = class_names("table-pagination__page", "table-pagination__page--current": current)
    if disabled
      tag.span(label, class: class_names(classes, "table-pagination__page--disabled"), "aria-disabled": true)
    else
      link_to label, url_for(request.query_parameters.merge("page" => number)), class: classes, rel: rel,
        "aria-current": (current ? "page" : nil)
    end
  end
end
