module TodosHelper
  def todo_status_options = Todo::STATUSES.map { |status| [ status.humanize, status ] }

  def todo_owner_options = User.active.people.ordered.map { |user| [ user.display_name, user.id ] }

  # The Work page's engagement filter: only engagements with open work (a large install has
  # hundreds of engagements, most with nothing to show here), and the one chosen, whatever it is.
  def todo_engagement_filter_options(current)
    engagements = Engagement.where(id: Todo.open.select(:engagement_id)).or(Engagement.where(ref: current)).order(:ref)
    engagements.map { |engagement| [ "#{engagement.ref} #{engagement.title}", engagement.ref ] }
  end

  # The team for the inline owner picker, loaded once per page however many rows use it.
  def todo_people = @todo_people ||= User.active.people.ordered.to_a

  # The status picker's choices, on the page once like the owner picker's.
  def todo_status_options_template
    return if @todo_status_options_rendered

    @todo_status_options_rendered = true
    tag.template(id: "todo-status-options") do
      safe_join(Todo::STATUSES.map do |status|
        tag.li(class: "popup__item", role: "checkbox", aria: { checked: false }, data: { picker_value: status }) do
          tag.button(type: "submit", name: "todo[status]", value: status, class: "btn popup__btn full-width", data: { action: "picker#choose" }) do
            safe_join([ tag.span(tag.span(class: "status-dot status-dot--#{status.dasherize}", aria: { hidden: true }), class: "display-contents", data: { picker_part: "dot" }),
              tag.span(status.humanize, class: "overflow-ellipsis flex-item-grow", data: { picker_part: "label" }),
              icon_tag("check", class: "checked flex-item-justify-end") ])
          end
        end
      end)
    end
  end

  # The owners picker's people, on the page once like the others; each click puts that person on
  # the work or takes them off (Todos::AssignmentsController).
  def todo_assignee_options_template
    return if @todo_assignee_options_rendered

    @todo_assignee_options_rendered = true
    tag.template(id: "todo-assignee-options") do
      safe_join(todo_people.map do |person|
        tag.li(class: "popup__item", role: "checkbox", aria: { checked: false }, data: { filter_target: "item", picker_value: person.id }) do
          tag.button(type: "submit", name: "assignee_id", value: person.id, class: "btn popup__btn full-width", data: { action: "picker#choose" }) do
            safe_join([ avatar_image_tag(person, class: "owner-picker__avatar owner-picker__avatar--small", alt: ""),
              tag.span(person.display_name, class: "overflow-ellipsis flex-item-grow"),
              icon_tag("check", class: "checked flex-item-justify-end") ])
          end
        end
      end)
    end
  end

  # Everyone on a piece of work as overlapping avatars, the lead first (preload assignments: :user).
  def todo_owners_tag(todo, limit: 3, fallback: nil)
    owners = todo.owners
    return (fallback ? tag.span(fallback, class: "person__none") : "".html_safe) if owners.empty?

    shown = owners.first(limit)
    rest = owners.size - shown.size
    tag.span class: "owner-stack", title: todo_owners_label(todo) do
      safe_join(shown.map { person_tag(it) } + [ (tag.span("+#{rest}", class: "owner-stack__more") if rest.positive?) ].compact)
    end
  end

  def todo_owners_label(todo)
    owners = todo.owners
    return "Unassigned" if owners.empty?

    ([ "#{owners.first.display_name}#{" (lead)" if owners.size > 1}" ] + owners.drop(1).map(&:display_name)).to_sentence
  end

  def todo_details(todo, with_engagement: false)
    [
      (todo.engagement.ref if with_engagement),
      (todo.engagement.client.name if with_engagement),
      (l(todo.due_on, format: :short) if todo.due_on),
      ("Internal" unless todo.client_visible?)
    ].compact.join(" · ")
  end
end
