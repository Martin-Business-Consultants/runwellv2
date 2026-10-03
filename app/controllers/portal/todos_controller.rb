class Portal::TodosController < Portal::BaseController
  agent_tool :portal_work, on: :index, title: "The work being done for you",
    description: "Everything shared with you across your engagements, with its status and due date."

  def index
    @todos = Todo.client_visible.joins(:engagement).where(engagements: { client_id: client.id })
                 .includes(:engagement, :scope_item).order(:due_on)
  end
end
