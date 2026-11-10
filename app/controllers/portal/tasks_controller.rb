class Portal::TasksController < Portal::BaseController
  agent_tool :portal_tasks, on: :index, title: "The work being done for you",
    description: "Everything shared with you, on your work or not, in your order of priority (portal_prioritize_task changes it), with its status, due date and whether it holds a message you haven't read. status: open (the default), done or all. q: words to find in their titles.",
    params: { status: %w[open done all], q: "string" }, next_tools: %i[portal_task]
  agent_tool :portal_task, on: :show, title: "One task, with its discussion",
    description: "A task shared with you (its id, from portal_tasks or portal_work): what it is, who has it, its documents, and the messages either side wrote on it, oldest first. portal_reply_on_task answers.",
    next_tools: %i[portal_reply_on_task]

  def index
    @state = Task.state_filter(params[:status])
    shared = Task.client_visible.where(client: client)
    @counts = { "open" => shared.open.count, "done" => shared.where(status: "done").count, "all" => shared.count }
    shared = shared.where("lower(tasks.title) LIKE ?", "%#{Task.sanitize_sql_like(params[:q].to_s.downcase.strip)}%") if params[:q].present?
    @tasks = portal_page(Task.state_scope(shared, @state).includes(:work, :scope_item).by_client_priority.order(:due_on, :position, :id))
  end

  # For their agent, the task whole; a person opens it in the side sheet, over the list.
  def show
    @task = client.tasks.client_visible.includes(:work, :scope_item, :contact, :owner, assignments: :user).find(params[:id])
    respond_to do |format|
      format.json
      format.html { redirect_to portal_tasks_path(task: @task.id, status: "all") }
    end
  end
end
