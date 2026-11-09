class Portal::WorksController < Portal::BaseController
  STATES = %w[active closed all].freeze

  agent_tool :portal_works, on: :index, title: "Your works",
    description: "The work we run for you, in your order of priority (portal_prioritize_work changes it), each with its ref (like WO-12), title and state. state: active (the default), closed or all.",
    params: { state: STATES }
  agent_tool :portal_work, on: :show, title: "One work: its parts, the work, and its documents",
    description: "Give its ref (WO-12) or title. Its sections and how each is going, the tasks shared with you, and its documents. section: one section's id (from sections) for only its tasks.",
    params: { section: "integer" }, next_tools: %i[portal_send_request]

  def index
    # Active work to start (the filter swaps ?state=), with how many each choice holds.
    @state = params[:state].presence_in(STATES) || "active"
    works = client.works
    @counts = { "active" => works.open.count, "closed" => works.closed.count, "all" => works.count }
    works = { "active" => works.open, "closed" => works.closed }.fetch(@state, works)
    @works = works.by_client_priority.ordered.includes(:client)
  end

  def show
    @work = client.works.includes(scope_items: :tasks).find_by_ref!(params[:ref])
    @task_state = Task.state_filter(params[:tasks])
    # One section's tasks (clicked in the sidebar), or all of them.
    @section = @work.scope_items.find { it.id.to_s == params[:section].to_s } if params[:section].present?
  end
end
