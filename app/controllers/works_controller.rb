class WorksController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  require_permission :close_works, only: %i[close reopen]
  agent_tool :list_works, on: :index, title: "List works",
    description: "open (the default), internal (open, on the business itself), closed or all.",
    params: { state: Work::FILTERS, label: Work::LABELS + %w[all] }
  agent_tool :show_work, on: :show, title: "Show a piece of work",
    description: "A piece of work with its sections (scope items), tasks, notes, documents and history.",
    next_tools: %i[add_scope_item create_task]
  agent_tool :create_work, on: :create, route: "/work", title: "Start a piece of work",
    description: "A project, work order or service for a client (or, for the internal client, your own project). It's active from the start: add sections (add_scope_item) to group its tasks, and tasks (create_task).",
    params: { work: { client_id: "integer!", label: Work::LABELS, shape: Work::SHAPES, title: "string!", description: "text", custom_fields: {} } },
    next_tools: %i[add_scope_item create_task]
  agent_tool :update_work, on: :update, title: "Change a piece of work",
    params: { work: { title: "string", description: "text", label: Work::LABELS, shape: Work::SHAPES, custom_fields: {} } }
  agent_tool :delete_work, on: :destroy, title: "Delete a piece of work",
    description: "Only while it has no tasks: its sections, notes and documents go with it. Otherwise close it."
  agent_tool :close_work, on: :close, title: "Mark a piece of work complete, or cancel it",
    description: "outcome: completed (delivered; the default) or cancelled (stopped before then). Either way it's closed: off the open list, its tasks and history kept. Only an active one closes: to change how a closed one ended, reopen_work it first.",
    params: { outcome: Work::CLOSE_OUTCOMES, reason: "string" }
  agent_tool :reopen_work, on: :reopen, title: "Reopen a closed work",
    description: "Active again, as it was; its history keeps the close and the reopening. Only a closed one reopens."

  before_action :set_work, only: %i[show edit update destroy close reopen]

  sortable_columns ref: "works.ref", title: "works.title", type: "works.label",
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ]

  def index
    @view = index_view
    @state = Work.filter_from(params)
    @label = params[:label].presence_in(Work::LABELS) || "all"
    scope = Work.filtered(state: @state, label: @label, scope: Work.includes(:custom_values))
    @column_widths = column_widths(scope, :title, :client) if @view == "table"
    @works = paginate sorted(scope)
  end

  def show
    # The Tasks section shows open tasks unless asked for done or all (?tasks=done|all), for every
    # section or the one picked in the sidebar (?item=12, or "other" for tasks in none).
    @task_state = Task.state_filter(params[:tasks])
    @task_item = Task.section_focus(params[:item])
    # Its work as a list by section, or as the Work board (?task_view=board) for everyone's work on it.
    @task_view = params[:task_view] == "board" ? "board" : "list"
    if @task_view == "board"
      @board_filters = { "owner" => "any", "work" => @work.ref }
      @board = Task.filtered(owner: "any", work: @work.ref)
    end
    # A tab picked on the page: just the tabs' frame, not the whole page around it.
    render partial: "works/record_tab", locals: { work: @work } if turbo_frame_request_id == "record_tab"
  end

  def new
    @work = Work.new(client_id: params[:client_id], label: params[:label].presence || "work_order")
  end

  def create
    @work = Work.new(work_params.merge(created_by: current_user))
    if @work.save
      redirect_to @work, notice: "#{@work.title} started: add its #{Setting.current.term(:task, count: 2).downcase} as they come up."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @work.update(work_params.except(:client_id, :shape))
      redirect_to @work, notice: "#{@work.title} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @work.deletable?
      @work.destroy!
      return remove_row(@work, notice: "#{@work.title} deleted.") if row_removal?

      redirect_to works_path, notice: "#{@work.title} deleted."
    else
      alert = "#{@work.title} has #{Setting.current.term(:task, count: 2).downcase} on it, so it can’t be deleted. Close it instead."
      return refuse_in_place(alert) if row_removal?

      redirect_back fallback_location: @work, alert: alert
    end
  end

  def close
    return redirect_to(@work, alert: "#{@work.title} is already #{@work.state_label.downcase}. To close it another way, reopen it first.") unless @work.closable?

    @work.close!(reason: params[:reason].presence, outcome: params[:outcome])
    redirect_to @work, notice: "#{@work.title} #{@work.close_outcome}."
  end

  def reopen
    return redirect_to(@work, alert: "#{@work.title} is open.") unless @work.reopenable?

    @work.reopen!
    redirect_to @work, notice: "#{@work.title} is open again."
  end

  private
    def current_record = (@work if @work&.persisted?)


  # The page reads each section's work (its delivery state): loaded together rather than one query
  # per section.
  def set_work
    scope = action_name == "show" ? Work.includes(scope_items: :tasks) : Work
    @work = scope.find_by_ref!(params[:ref])
  end
  def work_params = params.expect(work: [ :client_id, :label, :shape, :title, :description, custom_fields: {} ])
end
