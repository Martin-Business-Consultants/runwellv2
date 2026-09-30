class ClientsController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :list_clients, on: :index, title: "List clients",
    description: "Active clients unless status says otherwise: active (the default), dormant, former or all.",
    params: { status: "string" }
  agent_tool :show_client, on: :show, title: "Show a client",
    description: "A client with its contacts, engagements, commitments, notes and documents.", next_tools: %i[create_contact create_engagement add_note]
  agent_tool :create_client, on: :create, title: "Add a client",
    description: "time_zone: where the client is, as a Rails name (\"Pacific Time (US & Canada)\") or IANA (\"America/Los_Angeles\"); blank means ours. Their portal, approval pages and emails show times in it.",
    params: { client: { name: "string!", status: Client::STATUSES, time_zone: "string", custom_fields: {} } }, next_tools: %i[create_contact create_engagement]
  agent_tool :update_client, on: :update, title: "Change a client",
    description: "time_zone: where the client is, as a Rails name (\"Pacific Time (US & Canada)\") or IANA (\"America/Los_Angeles\"); blank means ours. Their portal, approval pages and emails show times in it.",
    params: { client: { name: "string", status: Client::STATUSES, time_zone: "string", custom_fields: {} } }
  agent_tool :delete_client, on: :destroy, title: "Delete a client",
    description: "Removes the client with its contacts, commitments and notes. A client with engagements can’t be deleted: set its status to former instead."

  before_action :set_client, only: %i[show edit update destroy]

  def index
    @view = index_view
    @status = params[:status].presence_in(Client::STATUSES + %w[all]) || "active"
    scope = @status == "all" ? Client.all : Client.where(status: @status)
    @clients = paginate scope.ordered.includes(:contacts, :engagements, :custom_values)
  end

  def show
    @engagement_state = Engagement.filter_from(params, :engagements)
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)
    if @client.save
      @client.record_event!("client.created")
      redirect_to @client, notice: "Client added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "Client updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @client.destroy
      redirect_to clients_path, notice: "Client deleted."
    else
      redirect_to edit_client_path(@client), alert: "#{@client.name} has engagements, so it can’t be deleted."
    end
  end

  private

  def set_client = @client = Client.find(params[:id])
  def client_params = params.expect(client: [ :name, :status, :time_zone, custom_fields: {} ])
end
