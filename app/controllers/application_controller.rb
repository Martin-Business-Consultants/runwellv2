class ApplicationController < ActionController::Base
  include Authentication
  include Authorization # after Authentication, so its check runs once the session is loaded
  include AgentTools, AgentResponses
  include TableSorting
  allow_browser versions: :modern
  before_action { Current.source = Current.agent? ? "agent" : "app" }
  before_action :refuse_read_only_writes
  before_action :remember_host
  around_action :in_agency_time_zone

  private

  # The agency's time zone (Settings > Address), unless the environment's default stands. The
  # portal and approval pages switch to the client's own inside this.
  def in_agency_time_zone(&) = Time.use_zone(Setting.zone, &)

  public

  private

  def current_user = Current.user

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
    params[:view].presence_in(Setting::INDEX_VIEWS + extra) || Setting.current.index_view
  end

  TABLE_PAGE_SIZE = 13

  # One page of an index list, with @page for the view. Cards load more as you scroll, Fizzy's
  # way (geared_pagination: 15, then 30, 50, 100 a page); a table shows 13 rows a page with
  # numbered pages under it (table_pagination), so call it after setting @view. Agents reading
  # JSON get every record, as before.
  def paginate(records)
    return records unless request.format.html?

    set_page_and_extract_portion_from records, per_page: (TABLE_PAGE_SIZE if @view == "table")
    @page.records
  end
end
