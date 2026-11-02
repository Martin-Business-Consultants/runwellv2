# People, many at once: their role, or deactivate / reactivate them. The last active owner is
# skipped and named, as one at a time.
class Bulk::UsersController < ApplicationController
  include BulkAction
  require_permission :manage_people
  agent_tool :bulk_update_people, on: :update, title: "Change several people's role, or deactivate or reactivate them, at once",
    description: "role: owner, manager or member. status: deactivated signs them out everywhere; active lets them back in. The last active owner is skipped.",
    params: { ids: "integer[]!", user: { role: User::ROLES, status: %w[active deactivated] } }

  def update
    changes = params.expect(user: %i[role status])
    people = selected(User.people)

    if (role = changes[:role].presence_in(User::ROLES))
      apply_to_each(people, done: "Made %{count} #{role == "owner" ? "owners" : role.pluralize}", fallback: users_path) do |person|
        person.update(role: role) || person.errors.full_messages.to_sentence
      end
    elsif changes[:status] == "deactivated"
      apply_to_each(people, done: "Deactivated %{count}", fallback: users_path) do |person|
        next "already deactivated" if person.deactivated?
        person.deactivate! || person.errors.full_messages.to_sentence
      end
    elsif changes[:status] == "active"
      apply_to_each(people, done: "Reactivated %{count}", fallback: users_path) do |person|
        next "already active" if person.active?
        person.reactivate! || person.errors.full_messages.to_sentence
      end
    else
      redirect_back fallback_location: users_path, alert: "Pick a role or a status."
    end
  end
end
