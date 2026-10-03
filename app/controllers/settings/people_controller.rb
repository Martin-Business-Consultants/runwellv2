# Who is on the team, their roles, and invitations out.
class Settings::PeopleController < ApplicationController
  require_permission :manage_people
  agent_tool :list_people, on: :index, title: "List people, invitations and what each role can do"
  agent_tool :change_role, on: :update, title: "Change someone’s role", params: { user: { role: User::ROLES } }

  def index
    @people = User.people.includes(:agent).ordered.to_a.sort_by { [ it.deactivated? ? 1 : 0, User::ROLES.index(it.role) || User::ROLES.size ] }
    @invitations = Invitation.pending.ordered.includes(:invited_by)
    @invitation = Invitation.new
  end

  def update
    person = User.find(params[:id])
    if person.update(role: params.expect(user: :role)[:role])
      redirect_to settings_people_path, notice: "#{person.display_name} is now #{person.role == "owner" ? "an owner" : "a " + person.role}."
    else
      redirect_to settings_people_path, alert: person.errors.full_messages.to_sentence
    end
  end
end
