# The Tasks board (tasks/board/*): runeui's ui :board, a column per status, each column's first
# page of cards drawn with the board and the rest loading as it scrolls.
module TasksBoardHelper
  # The board's columns, in order: the planned stream, the doing columns, then done.
  def task_board_statuses = [ "planned", *Task::BOARD_COLUMNS, "done" ]

  # Each column's dot: its status's colour (tasks.css, the status dots'), through runeui's tone.
  def task_column_tone(status) = status.dasherize

  # Where a move into a column is sent: one endpoint per destination (the planned stream, a doing
  # column, done), the card named in the path (__card__, filled in by runeui's board).
  def task_drop_url(status)
    case status
    when "planned" then columns_task_drops_stream_path("__card__", task_board_filters)
    when "done" then columns_task_drops_closure_path("__card__", task_board_filters)
    else columns_task_drops_column_path("__card__", task_board_filters.merge(column_id: status))
    end
  end

  # A column's first page of cards, rendered with the board so it doesn't wait on a request of its
  # own (later pages load from Tasks::ColumnsController as the column scrolls, in the same order).
  def task_board_page(board, status)
    GearedPagination::Recordset.new(board.board_column(status)).page(1)
  end

  # The item at the end of a column with more cards to come: a lazy frame that fetches the next
  # page as it scrolls into view (Tasks::ColumnsController), whose answer puts that page's cards
  # in its place, followed by the next one of these (tasks/board/more).
  # shown, total: how many cards the column draws and has, where the page knows (the board's first
  # page, whose own last? would count the column again).
  def task_board_more(status, page, shown: nil, total: nil)
    return if total ? shown.to_i >= total : page.last?

    turbo_frame_tag "board-more-#{status}-#{page.number + 1}", src: tasks_column_path(status, task_board_filters.merge(page: page.next_param)),
      loading: :lazy, class: "task-board__more" do
      "Loading more…"
    end
  end

  # The filters the board's column frames and drops carry: the page's query (Tasks), or what the
  # page set (@board_filters: a piece of work's Tasks tab shows everyone's tasks on it).
  def task_board_filters
    @board_filters || request.query_parameters.slice("owner", "work", "made_by", "q").reverse_merge("owner" => "me")
  end
end
