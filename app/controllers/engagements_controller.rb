class EngagementsController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  require_permission :close_engagements, only: %i[close reopen]
  agent_tool :list_engagements, on: :index, title: "List engagements",
    description: "open (the default), internal (open, on the business itself), closed or all.",
    params: { state: Engagement::FILTERS, label: Engagement::LABELS + %w[all] }
  agent_tool :show_engagement, on: :show, title: "Show an engagement",
    description: "An engagement with its sections (scope items), work, notes, documents and history.",
    next_tools: %i[add_scope_item create_work]
  agent_tool :create_engagement, on: :create, route: "/engagements", title: "Start an engagement",
    description: "A project, work order or service for a client (or, for the internal client, your own project). It's active from the start: add sections (add_scope_item) to group its work, and work (create_work).",
    params: { engagement: { client_id: "integer!", label: Engagement::LABELS, shape: Engagement::SHAPES, title: "string!", description: "text", custom_fields: {} } },
    next_tools: %i[add_scope_item create_work]
  agent_tool :update_engagement, on: :update, title: "Change an engagement",
    params: { engagement: { title: "string", description: "text", label: Engagement::LABELS, shape: Engagement::SHAPES, custom_fields: {} } }
  agent_tool :delete_engagement, on: :destroy, title: "Delete an engagement",
    description: "Only while it has no work: its sections, notes and documents go with it. Otherwise close it."
  agent_tool :close_engagement, on: :close, title: "Mark an engagement complete, or cancel it",
    description: "outcome: completed (delivered; the default) or cancelled (stopped before then). Either way it's closed: off the open list, its work and history kept.",
    params: { outcome: Engagement::CLOSE_OUTCOMES, reason: "string" }
  agent_tool :reopen_engagement, on: :reopen, title: "Reopen a closed engagement"

  before_action :set_engagement, only: %i[show edit update destroy close reopen]

  sortable_columns ref: "engagements.ref", title: "engagements.title", type: "engagements.label",
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ]

  def index
    @view = index_view
    @state = Engagement.filter_from(params)
    @label = params[:label].presence_in(Engagement::LABELS) || "all"
    scope = Engagement.filtered(state: @state, label: @label, scope: Engagement.includes(:custom_values))
    @column_widths = column_widths(scope, :ref, :title, :client) if @view == "table"
    @engagements = paginate sorted(scope)
  end

  def show
    # The Work section shows open work unless asked for done or all (?work=done|all), for every
    # section or the one picked in the sidebar (?item=12, or "other" for work in none).
    @work_state = params[:work].presence_in(%w[open done all]) || "open"
    @work_item = params[:item] == "other" ? "other" : params[:item].presence&.to_i
    # Its work as a list by section, or as the Work board (?work_view=board) for everyone's work on it.
    @work_view = params[:work_view] == "board" ? "board" : "list"
    if @work_view == "board"
      @board_filters = { "owner" => "any", "engagement" => @engagement.ref }
      @board = Todo.filtered(owner: "any", engagement: @engagement.ref)
    end
  end

  def new
    @engagement = Engagement.new(client_id: params[:client_id], label: params[:label].presence || "work_order")
  end

  def create
    @engagement = Engagement.new(engagement_params.merge(created_by: current_user))
    if @engagement.save
      @engagement.record_event!("engagement.created")
      redirect_to @engagement, notice: "#{@engagement.ref} started: add its work as it comes up."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @engagement.update(engagement_params.except(:client_id, :shape))
      redirect_to @engagement, notice: "#{@engagement.ref} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @engagement.deletable?
      @engagement.destroy!
      return remove_row(@engagement, notice: "#{@engagement.ref} deleted.") if row_removal?

      redirect_to engagements_path, notice: "#{@engagement.ref} deleted."
    else
      alert = "#{@engagement.ref} has work on it, so it can’t be deleted. Close it instead."
      return refuse_in_place(alert) if row_removal?

      redirect_back fallback_location: @engagement, alert: alert
    end
  end

  def close
    @engagement.close!(reason: params[:reason].presence, outcome: params[:outcome])
    redirect_to @engagement, notice: "#{@engagement.ref} #{@engagement.close_outcome}."
  end

  def reopen
    return redirect_to(@engagement, alert: "#{@engagement.ref} is open.") unless @engagement.closed?

    @engagement.reopen!
    redirect_to @engagement, notice: "#{@engagement.ref} is open again."
  end

  private

  # The page reads each section's work (its delivery state): loaded together rather than one query
  # per section.
  def set_engagement
    scope = action_name == "show" ? Engagement.includes(scope_items: :todos) : Engagement
    @engagement = scope.find_by_ref!(params[:ref])
  end
  def engagement_params = params.expect(engagement: [ :client_id, :label, :shape, :title, :description, custom_fields: {} ])
end
