class CommitmentsController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :list_commitments, on: :index, title: "List commitments",
    params: { state: %w[open resolved], owner_kind: Commitment::OWNER_KINDS + %w[all] }
  agent_tool :create_commitment, on: :create, route: "/engagements/:engagement_ref/commitments", title: "Add a commitment to an engagement",
    description: "A promise with a date, by us or the client. owner: us, user:<id>, or client.",
    params: { commitment: { description: "string!", due_on: "date!", owner: "string!", source: "string" } }
  agent_tool :update_commitment, on: :update, title: "Change an open commitment",
    params: { commitment: { description: "string", due_on: "date", owner: "string", source: "string" } }
  agent_tool :resolve_commitment, on: :resolve, title: "Resolve a commitment",
    description: "Final once resolved.", params: { resolution: Commitment::RESOLUTIONS, note: "string" }
  agent_tool :delete_commitment, on: :destroy, title: "Delete an open commitment"

  sortable_columns description: "commitments.description", due: "commitments.due_on",
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ], status: "commitments.resolution"

  def index
    @view = index_view
    @state = params[:state].presence_in(%w[open resolved]) || "open"
    @owner_kind = params[:owner_kind].presence_in(Commitment::OWNER_KINDS) || "all"

    scope = @state == "resolved" ? Commitment.where.not(resolution: nil).order(resolved_at: :desc) : Commitment.open.ordered
    scope = scope.where(owner_kind: @owner_kind) unless @owner_kind == "all"
    @column_widths = column_widths(scope, :description, :client) if @view == "table"
    @commitments = paginate sorted(scope.includes(:client, :engagement, :user, :contact))
  end

  def create
    parent = params[:engagement_ref] ? Engagement.find_by_ref!(params[:engagement_ref]) : Client.find(params[:client_id])
    client = parent.is_a?(Engagement) ? parent.client : parent
    commitment = client.commitments.new(commitment_params)
    commitment.source = commitment.source.presence || Current.source
    commitment.engagement = parent if parent.is_a?(Engagement)
    if commitment.save
      commitment.record_event!("commitment.added")
      redirect_back fallback_location: parent, notice: "Commitment added."
    else
      redirect_back fallback_location: parent, alert: commitment.errors.full_messages.to_sentence
    end
  end

  def edit
    @commitment = Commitment.open.find(params[:id])
  end

  def update
    @commitment = Commitment.open.find(params[:id])
    if @commitment.update(commitment_params)
      redirect_to @commitment.engagement || @commitment.client, notice: "Commitment updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    commitment = Commitment.open.find(params[:id])
    commitment.destroy!
    redirect_back fallback_location: commitments_path, notice: "Commitment deleted."
  end

  def resolve
    commitment = Commitment.find(params[:id])
    commitment.resolve!(params.expect(:resolution).presence_in(Commitment::RESOLUTIONS) || "done", note: params[:note].presence)
    redirect_back fallback_location: commitments_path, notice: "Marked #{commitment.resolution}."
  end

  private

  def commitment_params = params.expect(commitment: %i[description due_on owner source])
end
