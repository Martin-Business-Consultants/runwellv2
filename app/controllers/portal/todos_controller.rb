class Portal::TodosController < Portal::BaseController
  agent_tool :portal_work, on: :index, title: "The work being done for you",
    description: "Everything shared with you, on your engagements or not, with its status and due date."

  def index
    @todos = Todo.client_visible.where(client: client).includes(:engagement, :scope_item).order(:due_on)
  end
end
