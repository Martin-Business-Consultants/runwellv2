module TasksBoardHelper
  # Fizzy's card_article_tag for a task. The card color comes from its column's CSS, since
  # views never carry inline styles.
  def task_article_tag(task, data: {}, **options, &block)
    tag.article id: dom_id(task, :article), class: token_list(options.delete(:class), "card--active": task.status == "in_progress"),
      data: data, **options, &block
  end

  def task_column_color(status)
    { "in_progress" => "var(--color-card-4)", "in_review" => "var(--color-card-6)", "blocked" => "var(--color-card-8)" }.fetch(status)
  end

  # A column's first page of cards, rendered with the board so it doesn't wait on a request of its
  # own (later pages load from Tasks::ColumnsController as the column scrolls, in the same order).
  def task_board_page(board, status)
    GearedPagination::Recordset.new(board.board_column(status)).page(1)
  end

  # The filters the board's column frames and drops carry: the page's query (Tasks), or what the
  # page set (@board_filters: a piece of work's Tasks tab shows everyone's tasks on it).
  def task_board_filters
    @board_filters || request.query_parameters.slice("owner", "work", "made_by", "q").reverse_merge("owner" => "me")
  end
end
