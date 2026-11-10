class Portal::SessionsController < Portal::BaseController
  skip_before_action :require_contact, only: %i[new create show update]
  skip_before_action :refuse_writes_while_previewing, only: :destroy
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_portal_session_path, alert: "Try again later." }
  bot_checked fallback: -> { new_portal_session_path }

  layout "public"

  # Marked as the sign-in page, as staff's is (SessionsController#new, the connection controller).
  def new
    response.set_header("X-Runwell-Sign-In", "1")
  end

  # Always answer the same way so the form does not reveal which emails exist.
  def create
    if (contact = Contact.with_portal_access.find_by(email: params[:email].to_s.strip.downcase))
      PortalMailer.with(contact: contact).magic_link.deliver_later
    end
    redirect_to new_portal_session_path, notice: "If that address belongs to a client contact, a sign-in link is on its way."
  end

  # The emailed link opens a page with a button rather than signing in on the GET, since mail
  # scanners open links before people do. It works once.
  def show
    redirect_to new_portal_session_path, alert: "That link has expired or been used. Request a new one." unless link_contact
  end

  def update
    contact = link_contact
    return redirect_to new_portal_session_path, alert: "That link has expired or been used. Request a new one." unless contact

    contact.update!(link_signed_in_at: Time.current)
    session_record = contact.portal_sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent)
    cookies.signed.permanent[:portal_session_id] = { value: session_record.id, httponly: true, same_site: :lax }
    redirect_to session.delete(:portal_return_to).presence&.then { it.start_with?("/portal") ? it : nil } || portal_root_path
  end

  # Signing out of a preview ends the preview, back to the contact's page.
  def destroy
    if Current.previewing?
      cookies.delete(:portal_preview)
      return redirect_to(edit_contact_path(Current.preview_contact), notice: "Back to your own view.")
    end

    Current.portal_session&.destroy
    cookies.delete(:portal_session_id)
    redirect_to new_portal_session_path, status: :see_other
  end

  private
    def link_contact
      @link_contact ||= Contact.find_by_token_for(:portal_login, params[:token])&.then { it if it.portal? }
    end
end
