class Columns::Todos::Drops::ColumnsController < ApplicationController
  allow_staff
  include TodoScoped, TodoBoardScoped
  agent_exempt :create, reason: "dragging on the board; update_work changes status"

  def create
    @status = params[:column_id].presence_in(Todo::BOARD_COLUMNS) or raise ActiveRecord::RecordNotFound
    @todo.move!(status: @status)
    @count = board_todos.where(status: @status).count
  rescue ActiveRecord::RecordInvalid => error
    refuse_move(error)
  end
end
