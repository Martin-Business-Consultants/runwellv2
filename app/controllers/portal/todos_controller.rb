class Portal::TodosController < Portal::BaseController
  def index
    @todos = Todo.client_visible.joins(:engagement).where(engagements: { client_id: client.id })
                 .includes(:engagement, :scope_item).order(:due_on)
  end
end
