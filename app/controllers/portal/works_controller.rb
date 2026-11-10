class Portal::WorksController < Portal::BaseController
  STATES = %w[active closed all].freeze

  agent_tool :portal_works, on: :index, title: "Your works",
    description: "The work we run for you, in your order of priority (portal_prioritize_work changes it), each with its ref (like WO-12), title, state, how many of its tasks are done and the next date due. state: active (the default), closed or all.",
    params: { state: STATES }
  agent_tool :portal_work, on: :show, title: "One work: its parts, the work, and its documents",
    description: "Give its ref (WO-12) or title. Its sections and how each is going, the tasks shared with you, and its documents. section: one section's id (from sections) for only its tasks.",
    params: { section: "integer" }, next_tools: %i[portal_task portal_send_request]

  # The portal's first page: the client's work, each with how far along it is. A dashboard above
  # it is a plugin's (the :portal_dashboard slot).
  def index
    # Active work to start (the filter swaps ?state=), with how many each choice holds.
    @state = params[:state].presence_in(STATES) || "active"
    works = client.works
    @counts = { "active" => works.open.count, "closed" => works.closed.count, "all" => works.count }
    works = { "active" => works.open, "closed" => works.closed }.fetch(@state, works)
    @works = works.by_client_priority.ordered.includes(:client).to_a
    load_progress
  end

  def show
    @work = client.works.includes(scope_items: :tasks).find_by_ref!(params[:ref])
    @task_state = Task.state_filter(params[:tasks])
    # One section's tasks (clicked in the sidebar), or all of them.
    @section = @work.scope_items.find { it.id.to_s == params[:section].to_s } if params[:section].present?
  end

  private
    # Per piece of work, from the tasks shared with the client: how many are done of how many, and
    # the next date an open one is due.
    def load_progress
      shared = Task.client_visible.where(work_id: @works.map(&:id))
      totals, done = shared.group(:work_id).count, shared.where(status: "done").group(:work_id).count
      next_due = shared.open.where.not(due_on: nil).group(:work_id).minimum(:due_on)
      @progress = @works.to_h { [ it.id, { total: totals.fetch(it.id, 0), done: done.fetch(it.id, 0), next_due: next_due[it.id]&.to_date } ] }
    end
end
