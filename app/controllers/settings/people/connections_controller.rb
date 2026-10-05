# Cutting off every app and script someone has connected (their personal tokens and OAuth
# connections). Agents can't revoke tokens, so this is a person's job.
class Settings::People::ConnectionsController < ApplicationController
  require_permission :manage_people
  agent_exempt :destroy, reason: "agents can't revoke tokens"

  def destroy
    person = User.people.find(params[:person_id])
    person.revoke_connections!
    redirect_to settings_person_path(person), notice: "Every app #{person.display_name} connected is cut off."
  end
end
