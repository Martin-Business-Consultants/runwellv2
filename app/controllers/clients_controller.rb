class ClientsController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :list_clients, on: :index, title: "List clients",
    description: "Active clients unless status says otherwise: active (the default), dormant, former or all.",
    params: { status: Client::STATUSES + %w[all] }
  agent_tool :show_client, on: :show, title: "Show a client",
    description: "A client with its contacts, work, open tasks, notes and documents.", next_tools: %i[create_contact create_work add_note]
  agent_tool :create_client, on: :create, title: "Add a client",
    description: "time_zone: where the client is, as a Rails name (\"Pacific Time (US & Canada)\") or IANA (\"America/Los_Angeles\"); blank means ours. Their portal, client-facing pages and emails show times in it. internal: yourself (the business or person running Runwell), whose works are internal projects.",
    params: { client: { name: "string!", status: Client::STATUSES, time_zone: "string", internal: "boolean", custom_fields: {} } }, next_tools: %i[create_contact create_work]
  agent_tool :update_client, on: :update, title: "Change a client",
    description: "time_zone: where the client is, as a Rails name (\"Pacific Time (US & Canada)\") or IANA (\"America/Los_Angeles\"); blank means ours. Their portal, client-facing pages and emails show times in it. internal: yourself (the business or person running Runwell), whose works are internal projects. Setting it dormant or former closes its open work as cancelled and marks its open tasks done; setting it active again reopens nothing.",
    params: { client: { name: "string", status: Client::STATUSES, time_zone: "string", internal: "boolean", custom_fields: {} } }
  agent_tool :delete_client, on: :destroy, title: "Delete a client",
    description: "Removes the client with its contacts, tasks and notes. A client with work can’t be deleted: set its status to former instead."

  before_action :set_client, only: %i[show edit update destroy]

  sortable_columns name: "clients.name", status: "clients.status"

  def index
    @view = index_view
    @status = params[:status].presence_in(Client::STATUSES + %w[all]) || "active"
    scope = @status == "all" ? Client.all : Client.where(status: @status)
    @column_widths = column_widths(scope, :name) if @view == "table"
    @clients = paginate sorted(scope.ordered.includes(:contacts, :works, :custom_values))
  end

  def show
    @work_state = Work.filter_from(params, :works)
    @task_state = Task.state_filter(params[:tasks])
    # A tab picked on the page: just the tabs' frame, not the whole page around it.
    render partial: "clients/record_tab", locals: { client: @client } if turbo_frame_request_id == "record_tab"
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)
    if @client.save
      redirect_to @client, notice: "Client added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    saved = @client.update(client_params)
    return answer_in_place(saved) if params[:from_list] && request.format.turbo_stream?

    if saved
      if params[:from_list]
        redirect_back fallback_location: clients_path, notice: [ "#{@client.name} is #{@client.status.humanize.downcase}.", @client.sunset_summary ].compact.join(" ")
      else
        redirect_to @client, notice: [ "Client updated.", @client.sunset_summary ].compact.join(" ")
      end
    elsif params[:from_list]
      redirect_back fallback_location: clients_path, alert: @client.errors.full_messages.to_sentence
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @client.destroy
      return remove_row(@client, notice: "#{@client.name} deleted.") if row_removal?

      redirect_to clients_path, notice: "Client deleted."
    else
      alert = "#{@client.name} has #{Setting.current.term(:work, count: 2).downcase}, so it can’t be deleted."
      return refuse_in_place(alert) if row_removal?

      redirect_to edit_client_path(@client), alert: alert
    end
  end

  private
    def current_record = (@client if @client&.persisted?)

    # The status badge on the clients table saved: answer with that badge, not the whole list.
    def answer_in_place(saved)
      @client.reload unless saved
      streams = [ turbo_stream.replace(helpers.dom_id(@client, :status), partial: "clients/status_picker", locals: { client: @client }) ]
      if saved
        streams << turbo_stream_flash(notice: "#{@client.name} is #{@client.status.humanize.downcase}. #{@client.sunset_summary}") if @client.sunset_summary
      else
        streams << turbo_stream_flash(alert: @client.errors.full_messages.to_sentence)
      end
      render turbo_stream: streams
    end


  def set_client = @client = Client.find(params[:id])
  # Whether a client is kept out of AI is a person's call, never an agent's.
  def client_params = params.expect(client: [ :name, :status, :time_zone, :internal, custom_fields: {} ])
end
