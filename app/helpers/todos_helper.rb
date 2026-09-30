module TodosHelper
  def todo_status_options = Todo::STATUSES.map { |status| [ status.humanize, status ] }

  def todo_owner_options = User.active.people.ordered.map { |user| [ user.display_name, user.id ] }

  # The team for the inline owner picker, loaded once per page however many rows use it.
  def todo_people = @todo_people ||= User.active.people.ordered.to_a

  def todo_details(todo, with_engagement: false)
    [
      (todo.engagement.ref if with_engagement),
      (todo.engagement.client.name if with_engagement),
      (l(todo.due_on, format: :short) if todo.due_on),
      ("Internal" unless todo.client_visible?)
    ].compact.join(" · ")
  end
end
