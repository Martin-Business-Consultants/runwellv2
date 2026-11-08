# View as a contact: someone on staff opens the client portal as one of a client's people, to see
# exactly what they see. A browser-only preview (a signed cookie beside the staff session, read by
# Portal::BaseController): read-only, so nothing is sent or changed in the client's name, and it
# ends with Stop viewing or when the browser closes. Recorded on the contact's history.
class Contacts::PreviewsController < ApplicationController
  allow_staff
  agent_exempt :create, reason: "a browser preview of the portal; an agent reads what a client sees through the portal's own tools with the client's token"
  agent_exempt :destroy, reason: "ends a browser preview of the portal"

  def create
    contact = Contact.active.find(params[:contact_id])
    contact.record_event!("contact.previewed")
    cookies.signed[:portal_preview] = { value: contact.id, httponly: true, same_site: :lax }
    redirect_to portal_root_path
  end

  def destroy
    cookies.delete(:portal_preview)
    redirect_to edit_contact_path(params[:contact_id]), notice: "Back to your own view."
  end
end
