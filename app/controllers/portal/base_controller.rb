# The client portal: a contact signed in by magic link sees their own client's
# work, visible tasks and can send a request. Their own agent can do the same with a
# token of theirs (Settings in the portal, or OAuth): a bearer request is answered as JSON and
# reaches only this contact's client, never a staff page.
class Portal::BaseController < ApplicationController
  allow_unauthenticated_access # the client's own surface: not a staff agent tool
  layout "portal"
  skip_before_action :render_side_panel
  before_action :require_contact
  # Again, now the client's token is known (require_contact): a read-only one changes nothing here
  # either, whether through the portal's MCP or straight at an action.
  before_action :refuse_read_only_writes
  before_action :refuse_writes_while_previewing
  before_action :render_portal_side_panel, if: -> { turbo_frame_request_id == "side_panel" && request.get? }
  # Before the page draws, so the task being opened no longer counts as unread on it.
  before_action :portal_side_panel_task, if: -> { request.get? && params[:task].present? }
  around_action :in_client_time_zone
  helper_method :current_contact, :client, :portal_side_panel_task, :portal_unread_task_ids

  private

  def current_contact = Current.contact

  # A task shared with this client, opened in the side sheet (?task=): only theirs, only shared,
  # only what this contact sees (Contact::PortalScope, as every page here reads).
  def portal_side_panel_task
    return unless current_contact && params[:task].present?

    @portal_side_panel_task ||= current_contact.portal_tasks.includes(:work, :scope_item, :contact, :owner, assignments: :user).find_by(id: params[:task])&.tap { mark_discussion_read(it) }
  end

  # Opening a task reads its discussion (not for staff viewing as them, nor their agent).
  def mark_discussion_read(task)
    task.discussion_read_by!(current_contact) if Current.portal_session && !Current.previewing?
  end

  # The shared tasks holding a message this contact hasn't read (Task::Discussion), once a request.
  def portal_unread_task_ids
    @portal_unread_task_ids ||= current_contact ? Task.unread_discussion_ids(current_contact).to_set : Set.new
  end

  # Opening or closing the sheet loads just its frame (the side-panel controller), as on staff pages.
  def render_portal_side_panel
    render partial: "portal/tasks/side_panel", locals: { task: portal_side_panel_task }, layout: false
  end

  # Checked on every request: an archived contact, or one whose portal access was switched
  # off, is signed out even with a live cookie (and their tokens stop working).
  def require_contact
    return require_contact_token if bearer_request?
    return if previewing_as_contact

    Current.portal_session ||= Session.find_by(id: cookies.signed[:portal_session_id]) if cookies.signed[:portal_session_id]
    return keep_portal_session_fresh if Current.contact&.portal? && !portal_session_idle?

    Current.portal_session&.destroy
    Current.portal_session = nil
    cookies.delete(:portal_session_id)
    session[:portal_return_to] = request.fullpath if request.get? && request.format.html? && !turbo_frame_request?
    redirect_to new_portal_session_path
  end

  # A session nobody has used in three months is over (Contact::PORTAL_SESSION_IDLE): they sign in
  # again by emailed link. Its last use is its updated_at, moved on at most once a day.
  def portal_session_idle? = Current.portal_session.present? && Current.portal_session.updated_at < Contact::PORTAL_SESSION_IDLE.ago

  def keep_portal_session_fresh
    Current.portal_session.touch if Current.portal_session && Current.portal_session.updated_at < 1.day.ago
  end

  # Someone on staff viewing as a contact (Contacts::PreviewsController): their staff session must
  # still be good, or the preview is dropped and the portal asks for a sign-in as usual.
  def previewing_as_contact
    return unless (id = cookies.signed[:portal_preview])

    if (staff = find_session_by_cookie) && (contact = Contact.find_by(id: id))
      Current.session = staff
      Current.preview_contact = contact
    else
      cookies.delete(:portal_preview)
      nil
    end
  end

  # A preview only looks: sending a request, connecting an app or anything else that writes would
  # do it in the client's name.
  def refuse_writes_while_previewing
    return unless Current.previewing? && !request.get? && !request.head?

    message = "You’re viewing as #{current_contact.name}: nothing is sent or changed. To send it for real, sign in as them with a portal link."
    # From a modal, an inline form or a drag (a stream request), the refusal answers in place: a
    # redirect would land inside the frame, and the form would close as if it had been sent.
    return render(turbo_stream: turbo_stream_flash(alert: message), status: :forbidden) if request.format.turbo_stream?

    redirect_back fallback_location: portal_root_path, alert: message
  end

  def require_contact_token
    token = AccessToken.authenticate_contact(bearer_token)
    return request_portal_token unless token
    return refuse_paused_token if token.paused?

    token.used!
    Current.access_token = token
  end

  # 401 pointing at how a connector signs a client in (OAuth, RFC 9728).
  def request_portal_token
    response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{oauth_protected_resource_url(resource: "portal/mcp")}")
    render json: { status: "error", code: "auth", summary: "Sign in first: this needs a valid client token.", hint: Agent::Errors.hint("auth") }, status: :unauthorized
  end

  def client = current_contact.client

  PAGE_SIZE = 25

  # One page of a portal list for a person (numbered pages under it, table_pagination); their agent
  # reading JSON gets it whole.
  def portal_page(records)
    return records unless request.format.html?

    set_page_and_extract_portion_from records, per_page: PAGE_SIZE
    @page.records
  end

  # Signed in, the contact sees times in their client's zone; the sign-in pages use ours.
  def in_client_time_zone(&action)
    current_contact ? client.in_time_zone(&action) : action.call
  end
end
