class Columns::Tasks::Drops::StreamsController < ApplicationController
  allow_staff
  include TaskScoped, TaskBoardScoped
  agent_exempt :create, reason: "dragging on the board; update_task changes status"

  def create
    @task.move!(status: "planned", before: params[:before])
    @count = board_tasks.where(status: "planned").count
  rescue ActiveRecord::RecordInvalid => error
    refuse_move(error)
  end
end
