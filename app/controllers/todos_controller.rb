class TodosController < ApplicationController
  include TodoBoardScoped
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :list_work, on: :index, title: "List work (todos)",
    params: { status: %w[open all planned in_progress in_review blocked], owner: "string", engagement: "string", due: %w[overdue today week] },
    description: "Todos across engagements. status: open (default), all, or one status; owner: me (the person you act for), none (nobody's on it), any, or a person’s id or name (work they lead or are on); engagement: a ref or all; due: overdue, today or week (the seven days after today)."
  agent_tool :show_work, on: :show, title: "Show a todo"
  agent_tool :create_work, on: :create, title: "Add work (a todo) to an engagement or a client",
    description: "Give engagement_ref for work on an engagement, or todo.client_id for work straight on a client. owner_id: who leads it; other_owner_ids: anyone else on it. Work with nobody on it is a request until someone takes it on. A promise with a date is work with a due date. contact_id: the client contact who asked for it; source: how it came in (app, phone, email…).",
    params: { engagement_ref: "string", todo: { title: "string!", description: "text", client_id: "integer", contact_id: "integer", source: "string", owner_id: "integer", other_owner_ids: "integer[]", due_on: "date", scope_item_id: "integer", client_visible: "boolean", custom_fields: {} } }
  agent_tool :update_work, on: :update, title: "Change a todo",
    description: "Change its status (planned, in_progress, in_review when finished and waiting for a person to check, blocked, done), owners, due date or details. owner_id is the lead (replacing the lead, keeping the others; blank hands the lead to whoever else is on it); other_owner_ids is everyone else on it (replaces them; [] for nobody else). Both blank: nobody. client_visible shows it in the client’s portal.",
    params: { todo: { title: "string", description: "text", status: Todo::STATUSES, client_id: "integer", contact_id: "integer", source: "string", owner_id: "integer", other_owner_ids: "integer[]", due_on: "date", scope_item_id: "integer", client_visible: "boolean", custom_fields: {} } }
  agent_tool :delete_work, on: :destroy, title: "Remove a todo"
  agent_tool :brief_work, on: :brief, title: "Get a brief for doing a todo",
    description: "Everything needed to do this todo and report back, as Markdown: the work, its engagement and agreed scope, recent notes, other open work with a date, repositories when the Code plugin is on, and how to update status and leave notes.",
    next_tools: %i[update_work add_note]

  before_action :set_todo, only: %i[show edit update destroy brief]

  sortable_columns title: "todos.title",
    engagement: [ "engagements.ref", ->(scope) { scope.left_joins(:engagement) } ],
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ],
    owner: [ "owners.name", ->(scope) { scope.joins("LEFT JOIN users owners ON owners.id = todos.owner_id") } ],
    due: "todos.due_on",
    status: "CASE todos.status #{Todo::STATUSES.each_with_index.map { |status, index| "WHEN '#{status}' THEN #{index}" }.join(" ")} END"

  STATUS_FILTERS = %w[open all planned in_progress in_review blocked].freeze

  def index
    @view = index_view(extra: %w[board])
    @status = params[:status].presence_in(STATUS_FILTERS) || "open"
    # The page opens on your own work; agents (JSON) list everyone unless they ask.
    @owner = params[:owner].presence || (request.format.json? ? "any" : "me")
    @engagement = params[:engagement].presence || "all"
    @due = params[:due].presence_in(Todo::DUE_FILTERS.keys) || "any"

    scope = Todo.filtered(owner: owner_filter, engagement: @engagement)
    scope = scope.public_send(Todo::DUE_FILTERS[@due]) unless @due == "any"
    @board = scope
    scope = scope.open if @status == "open"
    scope = scope.where(status: @status) unless @status.in?(%w[open all])
    @column_widths = column_widths(scope, :title, :engagement, :client) if @view == "table"
    @todos = paginate sorted(scope.includes(:custom_values).order(:due_on, :position, :id))
  end

  # On an engagement (its ref in the path), a client (client_id, or the client's page), or the record
  # picked in the quick action modal (g w n).
  def create
    home =
      if params[:engagement_ref] then Engagement.find_by_ref!(params[:engagement_ref])
      elsif params[:client_id] then Client.find(params[:client_id])
      elsif params[:record].present? then QuickAction.locate(params[:record], %w[Engagement Client])
      elsif params.dig(:todo, :client_id).present? then Client.find(params.dig(:todo, :client_id))
      end
    return redirect_back(fallback_location: todos_path, alert: "Choose the #{Setting.current.term(:engagement).downcase} or #{Setting.current.term(:client).downcase} it’s for.") unless home

    todo = home.todos.new(todo_params.merge(created_by: current_user))
    if todo.save
      todo.record_event!("todo.created")
      if params[:inline] == "work" && request.format.turbo_stream?
        render_work_section(home)
      else
        redirect_back fallback_location: home, notice: params[:record].present? ? "Added “#{todo.title}” to #{home_name(home)}." : "Added."
      end
    else
      return refuse_in_place(todo.errors.full_messages.to_sentence) if params[:inline] == "work" && request.format.turbo_stream?

      redirect_back fallback_location: home, alert: todo.errors.full_messages.to_sentence
    end
  end

  def show
  end

  def edit
  end

  def update
    saved = @todo.update(todo_params)
    if request.format.turbo_stream? && (params[:inline] == "panel" || (params[:inline].present? && side_panel_open_for?(@todo)))
      return refresh_under_panel(saved)
    end
    return answer_in_place(saved) if params[:inline].present? && request.format.turbo_stream?

    if saved
      if params[:from_edit]
        redirect_to @todo, notice: "Saved."
      else
        redirect_back fallback_location: todo_home
      end
    elsif params[:from_edit]
      render :edit, status: :unprocessable_entity
    else
      redirect_back fallback_location: todo_home, alert: @todo.errors.full_messages.to_sentence
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
    if row_removal?
      closing = side_panel_open_for?(@todo) ? [ turbo_stream.update("side_panel", "") ] : []
      return remove_row(@todo, notice: "Removed.", also: closing)
    end
    # From a list, stay on it; from the todo's own pages (now gone), go to its engagement.
    if request.referer.to_s.include?(todo_path(@todo))
      redirect_to todo_home, notice: "Removed."
    else
      redirect_back fallback_location: todo_home, notice: "Removed."
    end
  end

  private
    # The status picker on a list saved: answer with that picker as it now stands, and the
    # due date beside it (Overdue depends on the status), not a reload of the whole page. Refused,
    # the picker goes back to what was saved, and the reason shows.
    def answer_in_place(saved)
      @todo.reload unless saved
      labelled = params[:labelled].present?
      picker = "todos/status_dot"
      id = helpers.dom_id(@todo, "status#{"_labelled" if labelled}")
      flash.now[:alert] = @todo.errors.full_messages.to_sentence unless saved

      locals = { todo: @todo, labelled: labelled, options_on_page: true } # the page has the choices already
      streams = [ turbo_stream.replace(id, partial: picker, locals: locals),
                  turbo_stream.replace(helpers.dom_id(@todo, :due), partial: "todos/due", locals: { todo: @todo }) ]
      streams << turbo_stream.replace("flash", partial: "layouts/shared/flash") unless saved
      render turbo_stream: streams
    end

    def owner_filter = owner_filter_for(@owner)

    # Is this todo the one open in the side panel of the page that sent the change (?task=)?
    def side_panel_open_for?(todo)
      Rack::Utils.parse_query(URI(request.referer.to_s).query.to_s)["task"] == todo.id.to_s
    rescue URI::InvalidURIError
      false
    end

    # A change from the side panel (or to the todo open in it): the page under the panel, panel and
    # all, refreshes in place (a morph, scroll kept), so its row, card, counts and the panel agree.
    def refresh_under_panel(saved)
      if saved
        flash[:notice] = "Saved."
      else
        flash[:alert] = @todo.errors.full_messages.to_sentence
      end
      render turbo_stream: turbo_stream.refresh(request_id: nil)
    end

    # Added from the Work section on the engagement's or client's own page: that section again
    # (open work, and the section it was focused on) and the notice, without reloading the page.
    def render_work_section(home)
      flash.now[:notice] = "Added."
      section = if home.is_a?(Engagement)
        { partial: "todos/section", locals: { engagement: home, item: params[:inline_item].presence&.to_i } }
      else
        { partial: "todos/client_section", locals: { client: home } }
      end
      render turbo_stream: [ turbo_stream.replace("work", method: :morph, **section), turbo_stream.replace("flash", partial: "layouts/shared/flash") ]
    end

    def home_name(home) = home.is_a?(Engagement) ? "#{home.ref} #{home.title}" : home.name

    # Where the work lives: its engagement, else its client, else the requests it's among.
    def todo_home = @todo.engagement || @todo.client || todos_path(owner: "none")

  def set_todo = @todo = Todo.find(params[:id])
  def todo_params = params.expect(todo: [ :title, :description, :status, :client_id, :contact_id, :source, :owner_id, :due_on, :position, :client_visible, :scope_item_id, custom_fields: {}, other_owner_ids: [] ])
end
