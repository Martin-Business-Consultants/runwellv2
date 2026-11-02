# Settings > Roles: what each of the three roles may do, with the permissions plugins add. For
# everyone to read; a person's role is changed on their page in Users.
class Settings::RolesController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "a table of the roles; `me` explains the caller's own permissions"

  def show
  end
end
