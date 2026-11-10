# Signing a contact out of the portal everywhere (a lost phone, a shared computer), from their page.
# They sign in again with a fresh emailed link.
class Contacts::PortalSessionsController < ApplicationController
  allow_staff
  agent_tool :sign_contact_out_of_portal, on: :destroy, title: "Sign a contact out of the portal everywhere",
    description: "Ends every browser session they have in the portal. Their connected apps keep working; they sign in again by emailed link."

  def destroy
    contact = Contact.active.find(params[:contact_id])
    contact.sign_out_of_portal!
    redirect_back fallback_location: edit_contact_path(contact), notice: "#{contact.name} is signed out of the portal everywhere."
  end
end
