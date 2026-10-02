# Index tables sort by their column headers: ?sort=due&direction=desc. A controller names the
# columns it can sort by and how, and `sorted` applies the one in the URL; with none, the
# scope keeps its own order. The view's headers are `sortable_th` (TableSortingHelper), which
# reads `current_sort`. Only stored columns sort: a derived value (an engagement's state, a
# count) stays a plain header.
#
#   sortable_columns title: "todos.title",
#     client: [ "clients.name", ->(scope) { scope.left_joins(engagement: :client) } ],
#     due: "todos.due_on"
module TableSorting
  extend ActiveSupport::Concern

  DIRECTIONS = %w[asc desc].freeze

  included do
    class_attribute :table_sorts, instance_writer: false, default: {}
    helper_method :current_sort
  end

  class_methods do
    # Each column: an SQL expression, or [ expression, ->(scope) { scope with the joins it needs } ].
    def sortable_columns(**columns)
      self.table_sorts = columns.transform_keys(&:to_s)
    end
  end

  private

  # The column and direction in the URL, when this controller can sort by it.
  def current_sort
    return @current_sort if defined?(@current_sort)

    key = params[:sort].to_s
    @current_sort = table_sorts.key?(key) ? [ key, params[:direction].presence_in(DIRECTIONS) || "asc" ] : nil
  end

  # How wide each text column must be, in characters: its longest value across the whole list
  # (every page, so sorting or paging never moves a column), from the same expressions and joins
  # as sorting. Bold titles run wider than `ch`, hence the allowance; capped so one long title
  # wraps instead of taking the table. For table_colgroup.
  def column_widths(scope, *keys, min: 6, max: 40)
    measured = keys.map(&:to_s).select { table_sorts.key?(it) }
    return {} if measured.empty?

    base = scope.unscope(:order, :limit, :offset, :includes, :preload, :eager_load)
    joined = measured.reduce(base) { |relation, key| (joins = Array(table_sorts[key])[1]) ? joins.call(relation) : relation }
    lengths = Array(joined.pick(*measured.map { Arel.sql("MAX(LENGTH(#{Array(table_sorts[it]).first}))") }))

    measured.zip(lengths).to_h do |key, length|
      [ key.to_sym, ((length.to_i * 1.1).ceil + 2).clamp(min, max) ]
    end
  end

  # Empty values (no due date, no owner) sort last whichever way, then by id so pages are stable.
  def sorted(scope)
    key, direction = current_sort
    return scope unless key

    expression, joins = Array(table_sorts[key])
    scope = joins.call(scope) if joins
    scope.reorder(Arel.sql("#{expression} IS NULL"), Arel.sql("#{expression} #{direction.upcase}"), scope.model.arel_table[:id].asc)
  end
end
