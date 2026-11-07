module TodosBoardHelper
  # Fizzy's card_article_tag for a todo. The card color comes from its column's CSS, since
  # views never carry inline styles.
  def todo_article_tag(todo, data: {}, **options, &block)
    tag.article id: dom_id(todo, :article), class: token_list(options.delete(:class), "card--active": todo.status == "in_progress"),
      data: data, **options, &block
  end

  def todo_column_color(status)
    { "in_progress" => "var(--color-card-4)", "in_review" => "var(--color-card-6)", "blocked" => "var(--color-card-8)" }.fetch(status)
  end

  # A column's first page of cards, rendered with the board so it doesn't wait on a request of its
  # own (later pages load from Todos::ColumnsController as the column scrolls, in the same order).
  def todo_board_page(board, status)
    todos = board.where(status: status).then { status == "done" ? it.order(:due_on, :position) : it.board_ordered }
    GearedPagination::Recordset.new(todos).page(1)
  end

  # The filters the board's column frames and drops carry: the page's query (Work), or what the
  # page set (@board_filters: an engagement's Work tab shows everyone's work on it).
  def todo_board_filters
    @board_filters || request.query_parameters.slice("owner", "engagement").reverse_merge("owner" => "me")
  end
end
