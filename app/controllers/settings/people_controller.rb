# Who is on the team, their roles, and invitations out; and each person's page: their details, how
# they sign in, and what to do about it (Settings::People::*).
class Settings::PeopleController < ApplicationController
  require_permission :manage_people
  agent_tool :list_people, on: :index, title: "List people, invitations and what each role can do"
  agent_tool :show_person, on: :show, title: "Show someone on the team",
    description: "Their name, address, role, whether they're active, how they sign in (two-factor, connected apps, open sessions) and their recent sign-ins."
  agent_tool :update_person, on: :update, title: "Change someone’s name, address or role",
    params: { user: { name: "string", email_address: "string", role: User::ROLES } }

  def index
    @people = User.people.includes(:agent).ordered.to_a.sort_by { [ it.deactivated? ? 1 : 0, User::ROLES.index(it.role) || User::ROLES.size ] }
    @invitations = Invitation.pending.ordered.includes(:invited_by)
    @invitation = Invitation.new
  end

  def show
    @person = User.people.find(params[:id])
    @sessions = @person.sessions.order(updated_at: :desc).to_a
    @connections = @person.access_tokens.live.where.not(kind: "assistant").includes(:oauth_client).ordered.to_a
    @sign_ins = Event.where(subject: @person, kind: %w[user.signed_in user.sign_in_failed]).order(occurred_at: :desc).limit(8).to_a
  end

  def update
    person = User.people.find(params[:id])
    if person.update(params.expect(user: %i[name email_address role]))
      redirect_back_or_to settings_person_path(person), notice: "Saved #{person.display_name}: #{person.role == "owner" ? "an owner" : "a " + person.role}."
    else
      redirect_back_or_to settings_person_path(person), alert: person.errors.full_messages.to_sentence
    end
  end
end
