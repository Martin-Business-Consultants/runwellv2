class Tasks::ColumnsController < ApplicationController
  allow_staff
  include TaskBoardScoped
  agent_exempt :show, reason: "a board column in the browser; list_tasks covers it"

  def show
    @status = params[:id].presence_in(Task::STATUSES) or raise ActiveRecord::RecordNotFound
    # A page at a time (geared_pagination), the next loading as the column scrolls.
    set_page_and_extract_portion_from board_tasks.board_column(@status)
    @tasks = @page.records.to_a
    # The board's next page of this column (TasksBoardHelper#task_board_more): just its cards.
    if turbo_frame_request_id.to_s.start_with?("board-more-")
      render partial: "tasks/board/more", locals: { status: @status, page: @page, frame: turbo_frame_request_id }, layout: false
    else
      @total = board_tasks.where(status: @status).count
    end
  end
end
