json.summary "#{pluralize(@people.count(&:active?), "active person", plural: "active people")}, #{pluralize(@invitations.size, "pending invitation")}"
json.people @people do |person|
  json.merge! agent_user(person)
  json.extract! person, :email_address, :role
  json.active person.active?
  json.agent(person.agent && agent_user(person.agent))
end
json.invitations @invitations do |invitation|
  json.extract! invitation, :id, :email_address, :role, :sent_at
  json.expired invitation.expired?
  json.invited_by agent_user(invitation.invited_by)
end
json.roles User::ROLE_DESCRIPTIONS
json.permissions(User.permissions.transform_values { { name: it[:name], roles: it[:roles] } })
