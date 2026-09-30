class Columns::Todos::Drops::ClosuresController < ApplicationController
  allow_staff
  include TodoScoped, TodoBoardScoped
  agent_exempt :create, reason: "dragging on the board; update_work changes status"

  def create
    @todo.move!(status: "done")
    @count = board_todos.where(status: "done").count
  rescue ActiveRecord::RecordInvalid => error
    refuse_move(error)
  end
end
