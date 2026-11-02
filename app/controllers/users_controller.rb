# Who is on the team (Users, in the left nav): everyone sees the list and each person's name, address
# and role. People who manage people also see invitations, and on each person's page how they sign
# in and what to do about it (Users::*).
class UsersController < ApplicationController
  allow_staff
  require_permission :manage_people, only: :update
  agent_tool :list_people, on: :index, title: "List the people on the team",
    description: "Active people unless status says otherwise: active (the default), deactivated or all. For people who manage people, also pending invitations and what each role can do.",
    params: { status: "string" }
  agent_tool :show_person, on: :show, title: "Show someone on the team",
    description: "Their name, address and role. For people who manage people, also whether they're active and how they sign in (two-factor, connected apps, open sessions, recent sign-ins)."
  agent_tool :update_person, on: :update, title: "Change someone’s name, address or role",
    params: { user: { name: "string", email_address: "string", role: User::ROLES } }

  STATUSES = %w[active deactivated].freeze
  sortable_columns name: "users.name", email: "users.email_address", role: "users.role"

  def index
    @view = index_view
    @status = params[:status].presence_in(STATUSES + %w[all]) || "active"
    scope = @status == "all" ? User.people : User.people.public_send(@status)
    @column_widths = column_widths(scope, :name, :email) if @view == "table"
    @people = paginate sorted(scope.includes(:agent).ordered)
    @counts = { "active" => User.people.active.count, "deactivated" => User.people.deactivated.count }
    @invitations = can?(:manage_people) ? Invitation.pending.ordered.includes(:invited_by).to_a : []
  end

  def show
    @person = User.people.find(params[:id])
    return unless can?(:manage_people)

    @sessions = @person.sessions.order(updated_at: :desc).to_a
    @connections = @person.access_tokens.live.where.not(kind: "assistant").includes(:oauth_client).ordered.to_a
    @sign_ins = Event.where(subject: @person, kind: %w[user.signed_in user.sign_in_failed]).order(occurred_at: :desc).limit(8).to_a
  end

  def update
    person = User.people.find(params[:id])
    if person.update(params.expect(user: %i[name email_address role]))
      redirect_back_or_to user_path(person), notice: "Saved #{person.display_name}: #{person.role == "owner" ? "an owner" : "a " + person.role}."
    else
      redirect_back_or_to user_path(person), alert: person.errors.full_messages.to_sentence
    end
  end
end
