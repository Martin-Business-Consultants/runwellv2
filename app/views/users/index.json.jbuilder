json.summary "#{pluralize(@people.size, "#{@status == "all" ? "" : "#{@status} "}person", plural: "#{@status == "all" ? "" : "#{@status} "}people")}#{", #{pluralize(@invitations.size, "pending invitation")}" if can?(:manage_people)}"
json.people @people do |person|
  json.merge! agent_ref(person)
  json.extract! person, :email_address, :role
  json.active person.active?
  json.two_factor person.two_factor?
  json.agent(person.agent && agent_user(person.agent))
end
if can?(:manage_people)
  json.invitations @invitations do |invitation|
    json.extract! invitation, :id, :email_address, :role, :sent_at
    json.expired invitation.expired?
    json.invited_by agent_user(invitation.invited_by)
  end
  json.two_factor_required Setting.current.require_two_factor?
end
json.roles User::ROLE_DESCRIPTIONS
json.permissions(User.permissions.transform_values { { name: it[:name], roles: it[:roles] } })
