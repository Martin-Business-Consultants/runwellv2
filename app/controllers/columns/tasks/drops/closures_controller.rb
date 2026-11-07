class Columns::Tasks::Drops::ClosuresController < ApplicationController
  allow_staff
  include TaskScoped, TaskBoardScoped
  agent_exempt :create, reason: "dragging on the board; update_task changes status"

  def create
    @task.move!(status: "done")
    @count = board_tasks.where(status: "done").count
  rescue ActiveRecord::RecordInvalid => error
    refuse_move(error)
  end
end
