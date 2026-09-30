json.merge! agent_ref(contact)
json.extract! contact, :name, :role, :email, :phone, :portal_access, :can_approve
json.can_sign_in contact.portal?
