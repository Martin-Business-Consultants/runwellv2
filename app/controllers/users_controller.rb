# Everyone, the team and the people at clients (Contact, the client role) together (Users, in the
# left nav): everyone sees the list and each person's name, address and role; a client's person
# opens on their contact page. People who manage people also see invitations, and on each person's page how they sign
# in and what to do about it (Users::*).
class UsersController < ApplicationController
  allow_staff
  require_permission :manage_people, only: :update
  # Who a list shows: active (the default) or deactivated people, each a User scope; or all.
  STATUSES = %w[active deactivated].freeze

  agent_tool :list_people, on: :index, title: "List people: the team and clients' contacts",
    description: "Active people unless status says otherwise: active (the default), deactivated or all. who: everyone (the default), team (staff) or clients (clients' contacts, role client). For people who manage people, also pending invitations and what each role can do.",
    params: { status: STATUSES + %w[all], who: %w[everyone team clients] }
  agent_tool :show_person, on: :show, title: "Show someone on the team",
    description: "Their name, address and role. For people who manage people, also whether they're active and how they sign in (two-factor, connected apps, open sessions, recent sign-ins)."
  agent_tool :update_person, on: :update, title: "Change someone’s name, address or role",
    params: { user: { name: "string", email_address: "string", role: User::ROLES } }

  WHO = { "everyone" => -> { User.where(agent_owner_id: nil) }, "team" => -> { User.people }, "clients" => -> { User.clients } }.freeze
  sortable_columns name: "users.name", email: "users.email_address", role: "users.role",
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ]

  def index
    @view = index_view
    @status = params[:status].presence_in(STATUSES + %w[all]) || "active"
    @who = params[:who].presence_in(WHO.keys) || "everyone"
    people = WHO[@who].call
    scope = @status == "all" ? people : people.public_send(@status)
    @column_widths = column_widths(scope, :name, :email, :client) if @view == "table"
    @people = paginate sorted(scope.includes(:agent, :client).ordered)
    @counts = { "active" => people.active.count, "deactivated" => people.deactivated.count }
    @invitations = can?(:manage_people) ? Invitation.pending.ordered.includes(:invited_by).to_a : []
  end

  def show
    # Someone at a client is a contact: their page is the contact's.
    if (contact = Contact.find_by(id: params[:id])) && request.format.html?
      return redirect_to(edit_contact_path(contact))
    end

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
