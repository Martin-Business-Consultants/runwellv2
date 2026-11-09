class Portal::TasksController < Portal::BaseController
  agent_tool :portal_tasks, on: :index, title: "The work being done for you",
    description: "Everything shared with you, on your work or not, in your order of priority (portal_prioritize_task changes it), with its status and due date. status: open (the default), done or all.",
    params: { status: %w[open done all] }

  def index
    @state = Task.state_filter(params[:status])
    shared = Task.client_visible.where(client: client)
    @counts = { "open" => shared.open.count, "done" => shared.where(status: "done").count, "all" => shared.count }
    @tasks = Task.state_scope(shared, @state).includes(:work, :scope_item).by_client_priority.order(:due_on, :position, :id)
  end
end
