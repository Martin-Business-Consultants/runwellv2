class ApplicationController < ActionController::Base
  include Authentication
  include Authorization # after Authentication, so its check runs once the session is loaded
  include AgentTools, AgentResponses
  allow_browser versions: :modern
  before_action { Current.source = Current.agent? ? "agent" : "app" }
  before_action :refuse_read_only_writes

  private

  def current_user = Current.user

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

  # One page of an index list, Fizzy's way (geared_pagination: 15, then 30, 50, 100 a page),
  # with @page for the view's "load more". Agents reading JSON get every record, as before.
  def paginate(records)
    return records unless request.format.html?

    set_page_and_extract_portion_from records
    @page.records
  end
end
