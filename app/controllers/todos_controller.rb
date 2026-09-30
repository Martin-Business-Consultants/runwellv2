class TodosController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :list_work, on: :index, title: "List work (todos)",
    params: { status: %w[open all], owner: "string", engagement: "string" },
    description: "Todos across engagements. owner: me, none, any or a person’s id; engagement: a ref or all."
  agent_tool :show_work, on: :show, title: "Show a todo"
  agent_tool :create_work, on: :create, title: "Add work (a todo) to an engagement",
    params: { todo: { title: "string!", description: "text", owner_id: "integer", due_on: "date", scope_item_id: "integer", client_visible: "boolean", custom_fields: {} } }
  agent_tool :update_work, on: :update, title: "Change a todo",
    description: "Change its status (planned, in_progress, in_review when finished and waiting for a person to check, blocked, done), owner, due date or details. client_visible shows it in the client’s portal.",
    params: { todo: { title: "string", description: "text", status: Todo::STATUSES, owner_id: "integer", due_on: "date", scope_item_id: "integer", client_visible: "boolean", custom_fields: {} } }
  agent_tool :delete_work, on: :destroy, title: "Remove a todo"
  agent_tool :brief_work, on: :brief, title: "Get a brief for doing a todo",
    description: "Everything needed to do this todo and report back, as Markdown: the work, its engagement and agreed scope, recent notes, open commitments, repositories when the Code plugin is on, and how to update status and leave notes.",
    next_tools: %i[update_work add_note]

  before_action :set_todo, only: %i[show edit update destroy brief]

  def index
    @view = index_view(extra: %w[board])
    @status = params[:status].presence_in(%w[open all]) || "open"
    @owner = params[:owner].presence || "any"
    @engagement = params[:engagement].presence || "all"

    scope = Todo.filtered(owner: @owner, engagement: @engagement)
    @board = scope
    scope = scope.open unless @status == "all"
    @todos = paginate scope.includes(:custom_values).order(:due_on, :position, :id)
  end

  def create
    engagement = Engagement.find_by_ref!(params[:engagement_ref])
    todo = engagement.todos.new(todo_params.merge(created_by: current_user))
    if todo.save
      todo.record_event!("todo.created")
      redirect_back fallback_location: engagement, notice: "Added."
    else
      redirect_back fallback_location: engagement, alert: todo.errors.full_messages.to_sentence
    end
  end

  def show
  end

  def edit
  end

  def update
    if @todo.update(todo_params)
      if params[:from_edit]
        redirect_to @todo, notice: "Saved."
      else
        redirect_back fallback_location: @todo.engagement
      end
    elsif params[:from_edit]
      render :edit, status: :unprocessable_entity
    else
      redirect_back fallback_location: @todo.engagement, alert: @todo.errors.full_messages.to_sentence
    end
  end

  def brief
    @brief = Todo::Brief.new(@todo, base_url: request.base_url, person: current_user)
    respond_to do |format|
      format.text { render plain: @brief.to_s }
      format.json
    end
  end

  def destroy
    @todo.destroy
    # From a list, stay on it; from the todo's own pages (now gone), go to its engagement.
    if request.referer.to_s.include?(todo_path(@todo))
      redirect_to @todo.engagement, notice: "Removed."
    else
      redirect_back fallback_location: @todo.engagement, notice: "Removed."
    end
  end

  private

  def set_todo = @todo = Todo.find(params[:id])
  def todo_params = params.expect(todo: [ :title, :description, :status, :owner_id, :due_on, :position, :client_visible, :scope_item_id, custom_fields: {} ])
end
