class RequestsController < ApplicationController
  allow_staff
  require_permission :triage_requests, only: %i[promote_engagement promote_change promote_todo promote_commitment dismiss]
  require_permission :delete_records, only: :destroy
  agent_tool :list_requests, on: :index, title: "List requests", params: { status: Request::STATUSES + %w[all], source: "string" }
  agent_tool :show_request, on: :show, title: "Show a request", next_tools: %i[promote_request_to_todo promote_request_to_change dismiss_request]
  agent_tool :create_request, on: :create, title: "Log a request from a client",
    params: { request: { client_id: "integer", contact_id: "integer", sender_name: "string", sender_email: "string", subject: "string!", body: "text", source: "string", received_at: "string" } }
  agent_tool :update_request, on: :update, title: "Change an open request",
    params: { request: { client_id: "integer", contact_id: "integer", sender_name: "string", sender_email: "string", subject: "string", body: "text", source: "string" } }
  agent_tool :delete_request, on: :destroy, title: "Delete an open request"
  agent_tool :promote_request_to_engagement, on: :promote_engagement, title: "Triage: make a request a new engagement",
    params: { label: Engagement::LABELS, title: "string", client_id: "integer" }
  agent_tool :promote_request_to_change, on: :promote_change, title: "Triage: add a request as a scope item on a draft",
    params: { engagement_ref: "string!", price_cents: "integer" }
  agent_tool :promote_request_to_todo, on: :promote_todo, title: "Triage: make a request a todo",
    params: { engagement_ref: "string!", owner_id: "integer", due_on: "date" }
  agent_tool :promote_request_to_commitment, on: :promote_commitment, title: "Triage: make a request a commitment",
    params: { due_on: "date!", owner_kind: Commitment::OWNER_KINDS, user_id: "integer", engagement_ref: "string", client_id: "integer" }
  agent_tool :dismiss_request, on: :dismiss, title: "Triage: dismiss a request", params: { reason: "string" }

  before_action :set_request, except: %i[index new create]

  def index
    @view = index_view
    @status = params[:status].presence_in(Request::STATUSES + %w[all]) || "open"
    @source = params[:source].presence || "all"
    @requests = paginate Request.filtered(status: @status, source: @source)
  end

  def show
  end

  def new
    @request_record = Request.new(source: "email")
  end

  def create
    @request_record = Request.new(request_params)
    if @request_record.save
      @request_record.record_event!("request.received")
      redirect_to @request_record, notice: "Request logged."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to(@request, alert: "Only an open request can be edited.") unless @request.open?

    @request_record = @request
  end

  def update
    return redirect_to(@request, alert: "Only an open request can be edited.") unless @request.open?

    @request_record = @request
    if @request_record.update(request_params)
      redirect_to @request_record, notice: "Request updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    return redirect_to(@request, alert: "A triaged request stays as history.") unless @request.open?

    @request.destroy!
    redirect_to requests_path, notice: "Request deleted."
  end

  def promote_engagement
    @request.update!(client_id: params[:client_id]) if params[:client_id].present? && @request.client.nil?
    engagement = @request.promote_to_engagement!(label: params.require(:label), actor: current_user, title: params[:title])
    redirect_to engagement, notice: "Drafted #{engagement.ref} from the request."
  rescue ArgumentError => e
    redirect_to @request, alert: e.message
  end

  def promote_change
    engagement = Engagement.find_by_ref!(params.require(:engagement_ref))
    @request.promote_to_change!(engagement: engagement, actor: current_user, price_cents: params[:price_cents].to_i)
    redirect_to engagement, notice: "Added to #{engagement.ref}'s draft."
  rescue ArgumentError => e
    redirect_to @request, alert: e.message
  end

  def promote_todo
    engagement = Engagement.find_by_ref!(params.require(:engagement_ref))
    owner = User.find_by(id: params[:owner_id])
    @request.promote_to_todo!(engagement: engagement, actor: current_user, owner: owner, due_on: params[:due_on].presence)
    redirect_to engagement, notice: "Added as work on #{engagement.ref}."
  rescue ArgumentError => e
    redirect_to @request, alert: e.message
  end

  def promote_commitment
    @request.update!(client_id: params[:client_id]) if params[:client_id].present? && @request.client.nil?
    engagement = params[:engagement_ref].present? ? Engagement.find_by_ref!(params[:engagement_ref]) : nil
    @request.promote_to_commitment!(actor: current_user, due_on: params.require(:due_on), owner_kind: params[:owner_kind] || "us",
                                    user: User.find_by(id: params[:user_id]), engagement: engagement)
    redirect_to (engagement || @request.client), notice: "Commitment added."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @request, alert: e.message
  end

  def dismiss
    @request.dismiss!(reason: params[:reason].presence || "Not needed", actor: current_user)
    redirect_to requests_path, notice: "Dismissed."
  rescue ArgumentError => e
    redirect_to @request, alert: e.message
  end

  private

  def set_request = @request = Request.find(params[:id])
  def request_params = params.expect(request: %i[client_id contact_id sender_name sender_email subject body source received_at])
end
