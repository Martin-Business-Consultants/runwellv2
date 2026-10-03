class Todos::ColumnsController < ApplicationController
  allow_staff
  include TodoBoardScoped
  agent_exempt :show, reason: "a board column in the browser; list_work covers it"

  def show
    @status = params[:id].presence_in(Todo::STATUSES) or raise ActiveRecord::RecordNotFound
    todos = board_todos.where(status: @status).then { @status == "done" ? it.order(:due_on, :position) : it.board_ordered }
    # A page at a time (geared_pagination), the next loading as the column scrolls.
    set_page_and_extract_portion_from todos
    @todos = @page.records
  end
end
