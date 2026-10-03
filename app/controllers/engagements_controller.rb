class EngagementsController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  require_permission :close_engagements, only: :close
  agent_tool :list_engagements, on: :index, title: "List engagements",
    description: "By derived state: approved (the default: agreed and not closed), open (every open one), draft, sent, changes_requested, closed or all.",
    params: { state: Engagement::FILTERS, label: Engagement::LABELS + %w[all] }
  agent_tool :show_engagement, on: :show, title: "Show an engagement",
    description: "An engagement with its agreement versions (drafts and sent), scope, work, commitments, notes, documents and history.",
    next_tools: %i[create_agreement_version add_scope_item create_work]
  agent_tool :create_engagement, on: :create, route: "/engagements", title: "Start an engagement",
    description: "A project, work order or service for a client. Its agreement starts as a draft (create_agreement_version, add_scope_item), and it is sent to the client with send_agreement. For an internal client (the agency itself) it's an internal project: no agreement, add work straight away (create_work).",
    params: { engagement: { client_id: "integer!", label: Engagement::LABELS, shape: Engagement::SHAPES, title: "string!", description: "text", estimate_notes: "text", custom_fields: {} } },
    next_tools: %i[add_scope_item send_agreement]
  agent_tool :update_engagement, on: :update, title: "Change an engagement",
    params: { engagement: { title: "string", description: "text", estimate_notes: "text", label: Engagement::LABELS, shape: Engagement::SHAPES, custom_fields: {} } }
  agent_tool :delete_engagement, on: :destroy, title: "Delete an engagement",
    description: "Only while nothing was ever sent to the client: its draft, work and notes go with it."
  agent_tool :close_engagement, on: :close, title: "Close an engagement", params: { reason: "string" }

  before_action :set_engagement, only: %i[show edit update destroy close]

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
    # The Work section shows open work unless asked for done or all (?work=done|all).
    @work_state = params[:work].presence_in(%w[open done all]) || "open"
  end

  def new
    @engagement = Engagement.new(client_id: params[:client_id], label: params[:label].presence || "work_order")
  end

  def create
    @engagement = Engagement.new(engagement_params.merge(created_by: current_user))
    if @engagement.save
      @engagement.record_event!("engagement.created")
      if @engagement.internal?
        redirect_to @engagement, notice: "#{@engagement.ref} started. It's internal: add work as it comes up."
      else
        @engagement.draft_version!(actor: current_user)
        redirect_to @engagement, notice: "#{@engagement.ref} drafted."
      end
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
      redirect_to engagements_path, notice: "#{@engagement.ref} deleted."
    else
      redirect_back fallback_location: @engagement, alert: "#{@engagement.ref} was sent to the client, so it can’t be deleted. Close it instead."
    end
  end

  def close
    @engagement.close!(reason: params[:reason].presence)
    redirect_to @engagement, notice: "#{@engagement.ref} closed."
  end

  private

  # The page reads every version's decision and scope items, and each item's work (its delivery
  # state): loaded together rather than one query per version and item.
  def set_engagement
    scope = action_name == "show" ? Engagement.includes(agreement_versions: [ :approval, { scope_items: :todos } ]) : Engagement
    @engagement = scope.find_by_ref!(params[:ref])
  end
  def engagement_params = params.expect(engagement: [ :client_id, :label, :shape, :title, :description, :estimate_notes, custom_fields: {} ])
end
