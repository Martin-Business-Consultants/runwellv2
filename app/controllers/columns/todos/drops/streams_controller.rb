class Columns::Todos::Drops::StreamsController < ApplicationController
  allow_staff
  include TodoScoped, TodoBoardScoped
  agent_exempt :create, reason: "dragging on the board; update_work changes status"

  def create
    @todo.move!(status: "planned", before: params[:before])
    @todos = board_todos.where(status: "planned").board_ordered
  end
end
