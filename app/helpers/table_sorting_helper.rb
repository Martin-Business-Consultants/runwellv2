# Index tables (TableSorting). Their headers are runeui's ui :sort_header (UiHelper#list_table_th)
# and their pages ui :pagination (UiHelper#table_pagination); what's left here is the header
# plugins still call.
module TableSortingHelper
  # A column header that sorts the table by `key` (ui :sort_header): ascending first, then the
  # other way, keeping the page's filters and going back to the first page.
  def sortable_th(label, key, **options)
    current, direction = current_sort
    ui :sort_header, label: label, key: key, sort: current, direction: direction, **options
  end
end
