class Columns::Tasks::Drops::ColumnsController < ApplicationController
  allow_staff
  include TaskScoped, TaskBoardScoped
  agent_exempt :create, reason: "dragging on the board; update_task changes status"

  def create
    @status = params[:column_id].presence_in(Task::BOARD_COLUMNS) or raise ActiveRecord::RecordNotFound
    @task.move!(status: @status, before: params[:before])
    @count = board_tasks.where(status: @status).count
  rescue ActiveRecord::RecordInvalid => error
    refuse_move(error)
  end
end
