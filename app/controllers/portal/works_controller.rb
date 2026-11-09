class Portal::WorksController < Portal::BaseController
  agent_tool :portal_works, on: :index, title: "Your works",
    description: "All the work we run for you, in your order of priority (portal_prioritize_work changes it), each with its ref (like WO-12), title and state (active or closed)."
  agent_tool :portal_work, on: :show, title: "One work: its parts, the work, and its documents",
    description: "Give its ref (WO-12) or title. Its sections and how each is going, the tasks shared with you, and its documents.",
    next_tools: %i[portal_send_request]

  def index
    @works = client.works.by_client_priority.ordered.includes(:client)
  end

  def show
    @work = client.works.includes(scope_items: :tasks).find_by_ref!(params[:ref])
    @task_state = Task.state_filter(params[:tasks])
  end
end
