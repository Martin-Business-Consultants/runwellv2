class ApplicationController < ActionController::Base
  include Authentication
  include Authorization # after Authentication, so its check runs once the session is loaded
  include AgentTools, AgentResponses
  include TableSorting
  include BotChecked
  include NPlusOneDetection
  allow_browser versions: :modern
  # ReActionView registers its slots format, and Rails then answers a bare "*/*" (a plain fetch(),
  # like Lexxy's @mention list) in it: JSON where HTML was wanted, so the list read "Nothing
  # found". ReActionView's own requests name their type; a URL with a format keeps it.
  before_action { request.format = :html if request.accept.to_s.strip == "*/*" && params[:format].blank? }
  before_action { Current.source = Current.agent? ? "agent" : "app" }
  before_action :refuse_read_only_writes
  before_action :remember_host
  before_action :render_side_panel, if: -> { turbo_frame_request_id == "side_panel" && request.get? }
  around_action :in_install_time_zone
  helper_method :side_panel_todo

  private

  # The install's time zone (Settings > Address), unless the environment's default stands. The
  # portal and client-facing pages switch to the client's own inside this.
  def in_install_time_zone(&) = Time.use_zone(Setting.zone, &)

  public

  private

  def current_user = Current.user

  # The task open in the side panel (?task=42 on any staff page), or nil.
  def side_panel_todo
    return unless Current.user && !Current.agent? && params[:task].present?

    @side_panel_todo ||= Todo.includes(:engagement, :client, :scope_item, :owner, assignments: :user).find_by(id: params[:task])
  end

  # A record deleted from its table row (the table's one delete dialog sends inline=row): that row
  # goes and the notice shows, with no reload; a refusal shows where you are. Elsewhere, redirects.
  def row_removal? = params[:inline] == "row" && request.format.turbo_stream?

  def remove_row(record, notice:, also: [])
    flash.now[:notice] = notice
    render turbo_stream: [ turbo_stream.remove(helpers.dom_id(record, :row)), *also, turbo_stream.replace("flash", partial: "layouts/shared/flash") ]
  end

  def refuse_in_place(alert)
    flash.now[:alert] = alert
    render turbo_stream: turbo_stream.replace("flash", partial: "layouts/shared/flash"), status: :unprocessable_entity
  end

  # Opening or closing the side panel loads just its frame: the page under it stays as it is, so
  # its own action needn't run.
  def render_side_panel
    render partial: "layouts/shared/side_panel", locals: { todo: side_panel_todo }, layout: false
  end

  # Until someone sets the address (Settings > Address or APP_HOST), mail links to the one
  # signed-in people reach Runwell at (Runwell.host). Health checks and bare IPs don't count.
  def remember_host
    return unless Rails.env.production? && Current.user && !Runwell.host_set?
    return if request.host.blank? || request.host == "localhost" || request.host.match?(/\A[\d.]+\z|:/)

    Setting.current.update_column(:seen_host, request.host) unless Setting.current.seen_host == request.host
  end

  # A read-only token reads everything its person can and changes nothing. The MCP endpoint
  # is itself a POST; the write tools it dispatches come back through here and are refused.
  def refuse_read_only_writes
    return unless Current.access_token&.read_only? && !request.get? && !request.head? && !is_a?(McpController)

    render json: { status: "error", code: "read_only", summary: "This token is read-only: it can’t change anything.", hint: Agent::Errors.hint("read_only") }, status: :forbidden
  end

  # How an index shows its records: the view in the URL, else this install's default
  # (Settings > Views). Some indexes add their own, like Work's board.
  def index_view(extra: [])
    params[:view].presence_in(%w[table] + extra) || "table"
  end

  TABLE_PAGE_SIZE = 13

  # One page of an index list, with @page for the view. Cards load more as you scroll, Fizzy's
  # way (geared_pagination: 15, then 30, 50, 100 a page); a table shows 13 rows a page with
  # numbered pages under it (table_pagination), so call it after setting @view. Agents reading
  # JSON get every record, as before. A ReActionView state request (the slots format) renders the
  # same page, so it pages too.
  def paginate(records)
    return records unless request.format.html? || request.format.symbol == :slots

    set_page_and_extract_portion_from records, per_page: TABLE_PAGE_SIZE
    @page.records
  end
end
