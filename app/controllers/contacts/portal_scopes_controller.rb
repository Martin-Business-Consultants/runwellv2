# What a contact sees in the portal (Contact::PortalScope): everything shared with their client, or
# only some of its work, chosen on their page.
class Contacts::PortalScopesController < ApplicationController
  allow_staff
  agent_tool :set_contact_portal_scope, on: :update, title: "Choose what a contact sees in the portal",
    description: "limited: true to show them only some of their client's work (works: its refs or titles), with the tasks and files on it and anything they asked for themselves; false to show everything shared with the client again. They're never told about what they can't see.",
    params: { scope: { limited: "boolean!", works: "string[]" } },
    confirm: "This changes what the contact sees of their company’s work in the portal."

  def update
    contact = Contact.active.find(params[:contact_id])
    scope = params.expect(scope: [ :limited, works: [] ])
    names = Array(scope[:works]).compact_blank
    works = contact.client.works.where(ref: names.map { it.to_s.upcase }).or(contact.client.works.where(title: names)) if scope.key?(:works)
    contact.set_portal_scope!(limited: ActiveModel::Type::Boolean.new.cast(scope[:limited]), works: works)
    redirect_back fallback_location: edit_contact_path(contact), notice: "#{contact.name} now sees #{contact.portal_scope_label} in the portal."
  end
end
