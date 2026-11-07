class Tasks::ColumnsController < ApplicationController
  allow_staff
  include TaskBoardScoped
  agent_exempt :show, reason: "a board column in the browser; list_tasks covers it"

  def show
    @status = params[:id].presence_in(Task::STATUSES) or raise ActiveRecord::RecordNotFound
    # A page at a time (geared_pagination), the next loading as the column scrolls.
    set_page_and_extract_portion_from board_tasks.board_column(@status)
    @tasks = @page.records
  end
end
