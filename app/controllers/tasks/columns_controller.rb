class Tasks::ColumnsController < ApplicationController
  allow_staff
  include TaskBoardScoped
  agent_exempt :show, reason: "a board column in the browser; list_tasks covers it"

  def show
    @status = params[:id].presence_in(Task::STATUSES) or raise ActiveRecord::RecordNotFound
    tasks = board_tasks.where(status: @status).then { @status == "done" ? it.order(:due_on, :position) : it.board_ordered }
    # A page at a time (geared_pagination), the next loading as the column scrolls.
    set_page_and_extract_portion_from tasks
    @tasks = @page.records
  end
end
