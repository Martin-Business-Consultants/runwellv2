module TodoScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_todo
  end

  private

  def set_todo = @todo = Todo.find(params[:todo_id])
end
