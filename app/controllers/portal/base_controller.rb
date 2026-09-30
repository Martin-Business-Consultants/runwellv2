# The client portal: a contact signed in by magic link sees their own client's
# engagements, visible work and can send a request.
class Portal::BaseController < ApplicationController
  allow_unauthenticated_access # the client's own surface: not a staff agent tool
  layout "portal"
  before_action :require_contact
  around_action :in_client_time_zone
  helper_method :current_contact

  private

  def current_contact = Current.contact

  # Checked on every request: an archived contact, or one whose portal access was switched
  # off, is signed out even with a live cookie.
  def require_contact
    Current.portal_session ||= PortalSession.find_by(id: cookies.signed[:portal_session_id]) if cookies.signed[:portal_session_id]
    return if Current.contact&.portal?

    Current.portal_session&.destroy
    Current.portal_session = nil
    cookies.delete(:portal_session_id)
    redirect_to new_portal_session_path
  end

  def client = current_contact.client

  # Signed in, the contact sees times in their client's zone; the sign-in pages use ours.
  def in_client_time_zone(&action)
    current_contact ? client.in_time_zone(&action) : action.call
  end
end
