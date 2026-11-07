class Portal::TasksController < Portal::BaseController
  agent_tool :portal_tasks, on: :index, title: "The work being done for you",
    description: "Everything shared with you, on your work or not, with its status and due date."

  def index
    @tasks = Task.client_visible.where(client: client).includes(:work, :scope_item).order(:due_on)
  end
end
