class Portal::SessionsController < Portal::BaseController
  skip_before_action :require_contact, only: %i[new create show]
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_portal_session_path, alert: "Try again later." }

  layout "public"

  def new
  end

  # Always answer the same way so the form does not reveal which emails exist.
  def create
    if (contact = Contact.with_portal_access.find_by(email: params[:email].to_s.strip.downcase))
      PortalMailer.with(contact: contact).magic_link.deliver_later
    end
    redirect_to new_portal_session_path, notice: "If that address belongs to a client contact, a sign-in link is on its way."
  end

  def show
    contact = Contact.find_by_token_for(:portal_login, params[:token])
    return redirect_to new_portal_session_path, alert: "That link has expired. Request a new one." unless contact&.portal?

    session_record = contact.portal_sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent)
    cookies.signed.permanent[:portal_session_id] = { value: session_record.id, httponly: true, same_site: :lax }
    redirect_to session.delete(:portal_return_to).presence&.then { it.start_with?("/portal") ? it : nil } || portal_root_path
  end

  def destroy
    Current.portal_session&.destroy
    cookies.delete(:portal_session_id)
    redirect_to new_portal_session_path, status: :see_other
  end
end
