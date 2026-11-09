class TasksController < ApplicationController
  include TaskBoardScoped
  allow_staff
  require_permission :delete_records, only: :destroy

  # The list's status filter: open (the default), all, or one status short of done (all shows those).
  STATUS_FILTERS = (%w[open all] + Task::STATUSES.without("done")).freeze

  agent_tool :list_tasks, on: :index, title: "List tasks",
    params: { status: STATUS_FILTERS, owner: "string", work: "string", due: %w[overdue today week] },
    description: "Tasks across all work. status: open (default), all, or one status; owner: me (the person you act for), none (nobody's on it), any, or a person’s id or name (tasks they lead or are on); work: a ref or all; due: overdue, today or week (the seven days after today)."
  agent_tool :show_task, on: :show, title: "Show a task"
  agent_tool :create_task, on: :create, title: "Add a task to a piece of work or a client",
    description: "Give work_ref for a task on a piece of work, or task.client_id for a task straight on a client. owner_id: who leads it; other_owner_ids: anyone else on it. A task with nobody on it is a request until someone takes it on. A promise with a date is a task with a due date; repeat (weekly, biweekly, monthly, quarterly, yearly) makes the next one each time it's done. contact_id: the client contact who asked for it; source: how it came in (app, phone, email…).",
    params: { work_ref: "string", task: { title: "string!", description: "text", client_id: "integer", contact_id: "integer", source: "string", owner_id: "integer", other_owner_ids: "integer[]", due_on: "date", scope_item_id: "integer", client_visible: "boolean", repeat: Cadence::KEYS, custom_fields: {} } }
  agent_tool :update_task, on: :update, title: "Change a task",
    description: "Change its status (planned, in_progress, in_review when finished and waiting for a person to check, blocked, done), owners, due date or details. owner_id is the lead (replacing the lead, keeping the others; blank hands the lead to whoever else is on it); other_owner_ids is everyone else on it (replaces them; [] for nobody else). Both blank: nobody. client_visible shows it in the client’s portal. repeat (weekly, biweekly, monthly, quarterly, yearly; blank for never): marking it done makes the next one, due a period after this one.",
    params: { task: { title: "string", description: "text", status: Task::STATUSES, client_id: "integer", contact_id: "integer", source: "string", owner_id: "integer", other_owner_ids: "integer[]", due_on: "date", scope_item_id: "integer", client_visible: "boolean", repeat: Cadence::KEYS, custom_fields: {} } }
  agent_tool :delete_task, on: :destroy, title: "Remove a task"
  agent_tool :brief_task, on: :brief, title: "Get a brief for doing a task",
    description: "Everything needed to do this task and report back, as Markdown: the task, its work and agreed scope, recent notes, other open tasks with a date, repositories when the Code plugin is on, and how to update status and leave notes.",
    next_tools: %i[update_task add_note]

  before_action :set_task, only: %i[show edit update destroy brief]

  sortable_columns title: "tasks.title",
    work: [ "works.title", ->(scope) { scope.left_joins(:work) } ],
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ],
    owner: [ "owners.name", ->(scope) { scope.joins("LEFT JOIN users owners ON owners.id = tasks.owner_id") } ],
    due: "tasks.due_on",
    status: "CASE tasks.status #{Task::STATUSES.each_with_index.map { |status, index| "WHEN '#{status}' THEN #{index}" }.join(" ")} END"

  def index
    @view = index_view(extra: %w[board])
    @status = params[:status].presence_in(STATUS_FILTERS) || "open"
    # The page opens on your own tasks; agents (JSON) list everyone unless they ask.
    @owner = params[:owner].presence || (request.format.json? ? "any" : "me")
    @work_filter = params[:work].presence || "all"
    @due = params[:due].presence_in(Task::DUE_FILTERS.keys) || "any"

    scope = Task.filtered(owner: owner_filter, work: @work_filter)
    scope = scope.public_send(Task::DUE_FILTERS[@due]) unless @due == "any"
    @board = scope
    scope = scope.open if @status == "open"
    scope = scope.where(status: @status) unless @status.in?(%w[open all])
    @column_widths = column_widths(scope, :title, :work, :client) if @view == "table"
    @tasks = paginate sorted(scope.includes(:custom_values).order(:due_on, :position, :id))
  end

  # On a piece of work (its ref in the path), a client (client_id, or the client's page), or the record
  # picked in the quick action modal (g t n). Added in a Tasks section, that section comes back
  # (create.turbo_stream.erb); anywhere else, back where it was added.
  def create
    @home = home_from_params
    return redirect_back(fallback_location: tasks_path, alert: "Choose the #{Setting.current.term(:work).downcase} or #{Setting.current.term(:client).downcase} it’s for.") unless @home

    task = @home.tasks.new(task_params.merge(created_by: current_user))
    if task.save
      return render(:create) if inline?("tasks")

      redirect_back fallback_location: @home, notice: params[:record].present? ? "Added “#{task.title}” to #{home_name(@home)}." : "Added."
    else
      return refuse_in_place(task.errors.full_messages.to_sentence) if inline?("tasks")

      redirect_back fallback_location: @home, alert: task.errors.full_messages.to_sentence
    end
  end

  def show
  end

  def edit
  end

  # From the side panel, the task is redrawn wherever it shows (update.turbo_stream.erb); from its
  # edit page, back to it; anywhere else (an agent, a plain form), back where it came from.
  def update
    if @task.update(task_params)
      return render(:update) if inline?("panel")

      params[:from_edit] ? redirect_to(@task, notice: "Saved.") : redirect_back(fallback_location: task_home)
    elsif inline?("panel")
      @alert = @task.errors.full_messages.to_sentence
      @task.reload
      render :update, status: :unprocessable_entity
    elsif params[:from_edit]
      render :edit, status: :unprocessable_entity
    else
      redirect_back fallback_location: task_home, alert: @task.errors.full_messages.to_sentence
    end
  end

  def brief
    @brief = Task::Brief.new(@task, base_url: request.base_url, person: current_user)
    respond_to do |format|
      format.text { render plain: @brief.to_s }
      format.json
    end
  end

  # From its table row, just the row goes (and the side panel, if it showed this task); anywhere
  # else, to its work, client or the requests it was among.
  def destroy
    @task.destroy
    return remove_row(@task, notice: "Removed.", also: [ turbo_stream.remove(helpers.dom_id(@task, :panel)) ]) if row_removal?

    redirect_to task_home, notice: "Removed."
  end

  private
    def current_record = @task

    def owner_filter = owner_filter_for(@owner)

    # A form in place on a page (the side panel's fields, a Tasks section's Add) marks itself, and
    # is answered as a stream; the same action answers anything else with a redirect.
    def inline?(form) = params[:inline] == form && request.format.turbo_stream?

    def home_from_params
      if params[:work_ref] then Work.find_by_ref!(params[:work_ref])
      elsif params[:client_id] then Client.find(params[:client_id])
      elsif params[:record].present? then QuickAction.locate(params[:record], %w[Work Client])
      elsif params.dig(:task, :client_id).present? then Client.find(params.dig(:task, :client_id))
      end
    end

    def home_name(home) = home.is_a?(Work) ? home.title : home.name

    # Where the task lives: its work, else its client, else the requests it's among.
    def task_home = @task.work || @task.client || tasks_path(owner: "none")

    def set_task = @task = Task.find(params[:id])
    def task_params = params.expect(task: [ :title, :description, :status, :client_id, :contact_id, :source, :owner_id, :due_on, :position, :client_visible, :scope_item_id, :repeat, custom_fields: {}, other_owner_ids: [] ])
end
