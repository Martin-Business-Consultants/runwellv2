# The client portal: a contact signed in by magic link sees their own client's
# work, visible tasks and can send a request. Their own agent can do the same with a
# token of theirs (Settings in the portal, or OAuth): a bearer request is answered as JSON and
# reaches only this contact's client, never a staff page.
class Portal::BaseController < ApplicationController
  allow_unauthenticated_access # the client's own surface: not a staff agent tool
  layout "portal"
  before_action :require_contact
  before_action :refuse_writes_while_previewing
  around_action :in_client_time_zone
  helper_method :current_contact, :client

  private

  def current_contact = Current.contact

  # Checked on every request: an archived contact, or one whose portal access was switched
  # off, is signed out even with a live cookie (and their tokens stop working).
  def require_contact
    return require_contact_token if bearer_request?
    return if previewing_as_contact

    Current.portal_session ||= Session.find_by(id: cookies.signed[:portal_session_id]) if cookies.signed[:portal_session_id]
    return if Current.contact&.portal?

    Current.portal_session&.destroy
    Current.portal_session = nil
    cookies.delete(:portal_session_id)
    session[:portal_return_to] = request.fullpath if request.get?
    redirect_to new_portal_session_path
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

    redirect_back fallback_location: portal_root_path, alert: "You’re viewing as #{current_contact.name}: nothing is sent or changed."
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

  # Signed in, the contact sees times in their client's zone; the sign-in pages use ours.
  def in_client_time_zone(&action)
    current_contact ? client.in_time_zone(&action) : action.call
  end
end
