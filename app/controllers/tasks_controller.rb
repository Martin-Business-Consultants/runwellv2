class TasksController < ApplicationController
  include TaskBoardScoped
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :list_tasks, on: :index, title: "List tasks",
    params: { status: %w[open all planned in_progress in_review blocked], owner: "string", work: "string", due: %w[overdue today week] },
    description: "Tasks across all work. status: open (default), all, or one status; owner: me (the person you act for), none (nobody's on it), any, or a person’s id or name (tasks they lead or are on); work: a ref or all; due: overdue, today or week (the seven days after today)."
  agent_tool :show_task, on: :show, title: "Show a task"
  agent_tool :create_task, on: :create, title: "Add a task to a piece of work or a client",
    description: "Give work_ref for a task on a piece of work, or task.client_id for a task straight on a client. owner_id: who leads it; other_owner_ids: anyone else on it. A task with nobody on it is a request until someone takes it on. A promise with a date is a task with a due date. contact_id: the client contact who asked for it; source: how it came in (app, phone, email…).",
    params: { work_ref: "string", task: { title: "string!", description: "text", client_id: "integer", contact_id: "integer", source: "string", owner_id: "integer", other_owner_ids: "integer[]", due_on: "date", scope_item_id: "integer", client_visible: "boolean", custom_fields: {} } }
  agent_tool :update_task, on: :update, title: "Change a task",
    description: "Change its status (planned, in_progress, in_review when finished and waiting for a person to check, blocked, done), owners, due date or details. owner_id is the lead (replacing the lead, keeping the others; blank hands the lead to whoever else is on it); other_owner_ids is everyone else on it (replaces them; [] for nobody else). Both blank: nobody. client_visible shows it in the client’s portal.",
    params: { task: { title: "string", description: "text", status: Task::STATUSES, client_id: "integer", contact_id: "integer", source: "string", owner_id: "integer", other_owner_ids: "integer[]", due_on: "date", scope_item_id: "integer", client_visible: "boolean", custom_fields: {} } }
  agent_tool :delete_task, on: :destroy, title: "Remove a task"
  agent_tool :brief_task, on: :brief, title: "Get a brief for doing a task",
    description: "Everything needed to do this task and report back, as Markdown: the task, its work and agreed scope, recent notes, other open tasks with a date, repositories when the Code plugin is on, and how to update status and leave notes.",
    next_tools: %i[update_task add_note]

  before_action :set_task, only: %i[show edit update destroy brief]

  sortable_columns title: "tasks.title",
    work: [ "works.ref", ->(scope) { scope.left_joins(:work) } ],
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ],
    owner: [ "owners.name", ->(scope) { scope.joins("LEFT JOIN users owners ON owners.id = tasks.owner_id") } ],
    due: "tasks.due_on",
    status: "CASE tasks.status #{Task::STATUSES.each_with_index.map { |status, index| "WHEN '#{status}' THEN #{index}" }.join(" ")} END"

  STATUS_FILTERS = %w[open all planned in_progress in_review blocked].freeze

  def index
    @view = index_view(extra: %w[board])
    @status = params[:status].presence_in(STATUS_FILTERS) || "open"
    # The page opens on your own work; agents (JSON) list everyone unless they ask.
    @owner = params[:owner].presence || (request.format.json? ? "any" : "me")
    @work = params[:work].presence || "all"
    @due = params[:due].presence_in(Task::DUE_FILTERS.keys) || "any"

    scope = Task.filtered(owner: owner_filter, work: @work)
    scope = scope.public_send(Task::DUE_FILTERS[@due]) unless @due == "any"
    @board = scope
    scope = scope.open if @status == "open"
    scope = scope.where(status: @status) unless @status.in?(%w[open all])
    @column_widths = column_widths(scope, :title, :work, :client) if @view == "table"
    @tasks = paginate sorted(scope.includes(:custom_values).order(:due_on, :position, :id))
  end

  # On a piece of work (its ref in the path), a client (client_id, or the client's page), or the record
  # picked in the quick action modal (g t n).
  def create
    home =
      if params[:work_ref] then Work.find_by_ref!(params[:work_ref])
      elsif params[:client_id] then Client.find(params[:client_id])
      elsif params[:record].present? then QuickAction.locate(params[:record], %w[Work Client])
      elsif params.dig(:task, :client_id).present? then Client.find(params.dig(:task, :client_id))
      end
    return redirect_back(fallback_location: tasks_path, alert: "Choose the #{Setting.current.term(:work).downcase} or #{Setting.current.term(:client).downcase} it’s for.") unless home

    task = home.tasks.new(task_params.merge(created_by: current_user))
    if task.save
      task.record_event!("task.created")
      if params[:inline] == "tasks" && request.format.turbo_stream?
        render_task_section(home)
      else
        redirect_back fallback_location: home, notice: params[:record].present? ? "Added “#{task.title}” to #{home_name(home)}." : "Added."
      end
    else
      return refuse_in_place(task.errors.full_messages.to_sentence) if params[:inline] == "tasks" && request.format.turbo_stream?

      redirect_back fallback_location: home, alert: task.errors.full_messages.to_sentence
    end
  end

  def show
  end

  def edit
  end

  def update
    saved = @task.update(task_params)
    if request.format.turbo_stream? && (params[:inline] == "panel" || (params[:inline].present? && side_panel_open_for?(@task)))
      return refresh_under_panel(saved)
    end
    return answer_in_place(saved) if params[:inline].present? && request.format.turbo_stream?

    if saved
      if params[:from_edit]
        redirect_to @task, notice: "Saved."
      else
        redirect_back fallback_location: task_home
      end
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

  def destroy
    @task.destroy
    if row_removal?
      closing = side_panel_open_for?(@task) ? [ turbo_stream.update("side_panel", "") ] : []
      return remove_row(@task, notice: "Removed.", also: closing)
    end
    # From a list, stay on it; from the task's own pages (now gone), go to its work.
    if request.referer.to_s.include?(task_path(@task))
      redirect_to task_home, notice: "Removed."
    else
      redirect_back fallback_location: task_home, notice: "Removed."
    end
  end

  private
    # The status picker on a list saved: answer with that picker as it now stands, and the
    # due date beside it (Overdue depends on the status), not a reload of the whole page. Refused,
    # the picker goes back to what was saved, and the reason shows.
    def answer_in_place(saved)
      @task.reload unless saved
      labelled = params[:labelled].present?
      picker = "tasks/status_dot"
      id = helpers.dom_id(@task, "status#{"_labelled" if labelled}")
      flash.now[:alert] = @task.errors.full_messages.to_sentence unless saved

      locals = { task: @task, labelled: labelled, options_on_page: true } # the page has the choices already
      streams = [ turbo_stream.replace(id, partial: picker, locals: locals),
                  turbo_stream.replace(helpers.dom_id(@task, :due), partial: "tasks/due", locals: { task: @task }) ]
      streams << turbo_stream.replace("flash", partial: "layouts/shared/flash") unless saved
      render turbo_stream: streams
    end

    def owner_filter = owner_filter_for(@owner)

    # Is this task the one open in the side panel of the page that sent the change (?task=)?
    def side_panel_open_for?(task)
      Rack::Utils.parse_query(URI(request.referer.to_s).query.to_s)["task"] == task.id.to_s
    rescue URI::InvalidURIError
      false
    end

    # A change from the side panel (or to the task open in it): the page under the panel, panel and
    # all, refreshes in place (a morph, scroll kept), so its row, card, counts and the panel agree.
    def refresh_under_panel(saved)
      if saved
        flash[:notice] = "Saved."
      else
        flash[:alert] = @task.errors.full_messages.to_sentence
      end
      render turbo_stream: turbo_stream.refresh(request_id: nil)
    end

    # Added from the Work section on the work's or client's own page: that section again
    # (open work, and the section it was focused on) and the notice, without reloading the page.
    def render_task_section(home)
      flash.now[:notice] = "Added."
      section = if home.is_a?(Work)
        { partial: "tasks/section", locals: { work: home, item: params[:inline_item].presence&.to_i } }
      else
        { partial: "tasks/client_section", locals: { client: home } }
      end
      render turbo_stream: [ turbo_stream.replace("tasks", method: :morph, **section), turbo_stream.replace("flash", partial: "layouts/shared/flash") ]
    end

    def home_name(home) = home.is_a?(Work) ? "#{home.ref} #{home.title}" : home.name

    # Where the work lives: its work, else its client, else the requests it's among.
    def task_home = @task.work || @task.client || tasks_path(owner: "none")

  def set_task = @task = Task.find(params[:id])
  def task_params = params.expect(task: [ :title, :description, :status, :client_id, :contact_id, :source, :owner_id, :due_on, :position, :client_visible, :scope_item_id, custom_fields: {}, other_owner_ids: [] ])
end
