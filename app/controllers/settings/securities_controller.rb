# Settings > Security: sign-in rules for the whole team (requiring two-factor sign-in).
class Settings::SecuritiesController < ApplicationController
  require_permission :manage_people
  agent_exempt :show, reason: "sign-in security is changed by a person in the browser"

  def show
  end
end
