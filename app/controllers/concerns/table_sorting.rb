# Index tables sort by their column headers: ?sort=due&direction=desc. A controller names the
# columns it can sort by and how, and `sorted` applies the one in the URL; with none, the
# scope keeps its own order. The view's headers are runeui's ui :sort_header
# (UiHelper#list_table_th), which writes those two params and reads `current_sort`. Only stored columns sort: a derived value (a piece of work's state, a
# count) stays a plain header.
#
#   sortable_columns title: "tasks.title",
#     client: [ "clients.name", ->(scope) { scope.left_joins(work: :client) } ],
#     due: "tasks.due_on"
module TableSorting
  extend ActiveSupport::Concern

  DIRECTIONS = %w[asc desc].freeze

  included do
    class_attribute :table_sorts, instance_writer: false, instance_predicate: false, default: {}
    # A public reader would count as an action (agent:coverage listed it as one with no tool).
    private :table_sorts
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

  # Empty values (no due date, no owner) sort last whichever way, then by id so pages are stable.
  def sorted(scope)
    key, direction = current_sort
    return scope unless key

    expression, joins = Array(table_sorts[key])
    scope = joins.call(scope) if joins
    scope.reorder(Arel.sql("#{expression} IS NULL"), Arel.sql("#{expression} #{direction.upcase}"), scope.model.arel_table[:id].asc)
  end
end
