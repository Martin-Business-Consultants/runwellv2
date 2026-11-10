# Inviting a contact to the portal: an email saying what it is, with a link that signs them in
# (Contact#invite_to_portal!). Only someone who can sign in: portal access on, with an address.
class Contacts::PortalInvitationsController < ApplicationController
  allow_staff
  agent_tool :invite_contact_to_portal, on: :create, title: "Invite a contact to the portal",
    description: "Emails them what the portal is and a link that signs them in, good for a week. They need portal access and an email address first (update_contact).",
    confirm: "The contact gets an email inviting them to the portal."

  def create
    contact = Contact.active.find(params[:contact_id])
    return redirect_back(fallback_location: edit_contact_path(contact), alert: "#{contact.name} can’t sign in yet: #{contact.portal_access? ? "add their email address" : "switch portal access on"} first.") unless contact.portal?

    contact.invite_to_portal!
    redirect_back fallback_location: edit_contact_path(contact), notice: "Invitation sent to #{contact.email}."
  end
end
