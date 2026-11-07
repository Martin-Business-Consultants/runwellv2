module TodosHelper
  def todo_status_options = Todo::STATUSES.map { |status| [ status.humanize, status ] }

  def todo_owner_options = User.active.people.ordered.map { |user| [ user.display_name, user.id ] }

  # The Work page's engagement filter: only engagements with open work (a large install has
  # hundreds of engagements, most with nothing to show here), and the one chosen, whatever it is.
  def todo_engagement_filter_options(current)
    engagements = Engagement.where(id: Todo.open.select(:engagement_id)).or(Engagement.where(ref: current)).order(:ref)
    engagements.map { |engagement| [ "#{engagement.ref} #{engagement.title}", engagement.ref ] }
  end

  # What a link that opens a todo in the side panel carries (side-panel controller); its href stays
  # the todo's own page, for a new tab or a modifier click.
  def side_panel_data(todo, **data)
    action = [ data.delete(:action), "side-panel#open" ].compact.join(" ")
    data.merge(action: action, side_panel_task_param: todo.id)
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
          tag.button(type: "submit", name: "todo[status]", value: status, class: "popup__btn", data: { action: "picker#choose" }) do
            safe_join([ tag.span(tag.span(class: "status-dot status-dot--#{status.dasherize}", aria: { hidden: true }), class: "status-dot-picker__dot", data: { picker_part: "dot" }),
              tag.span(status.humanize, class: "popup__label", data: { picker_part: "label" }),
              icon_tag("check", class: "checked") ])
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
          tag.button(type: "submit", name: "assignee_id", value: person.id, class: "popup__btn", data: { action: "picker#choose" }) do
            safe_join([ avatar_image_tag(person, class: "avatar owner-picker__avatar", alt: ""),
              tag.span(person.display_name, class: "popup__label"),
              icon_tag("check", class: "checked") ])
          end
        end
      end)
    end
  end

  # Everyone on a piece of work as overlapping avatars (rune_ui's avatar stack), the lead first and
  # on top (preload assignments: :user). hidden: inside a control whose own text names them (the
  # owner picker's trigger), so screen readers don't hear every name twice.
  def todo_owners_tag(todo, limit: 3, fallback: nil, hidden: false)
    owners = todo.owners
    return (fallback ? tag.span(fallback, class: "person__none") : "".html_safe) if owners.empty?

    shown = owners.first(limit)
    rest = owners.size - shown.size
    tag.span class: "avatar-stack owner-stack", title: (todo_owners_label(todo) unless hidden), aria: { hidden: (true if hidden) } do
      safe_join(shown.map { person_tag(it) } +
        [ (tag.span("+#{rest}", class: "avatar avatar--md avatar--more", title: owners.drop(limit).map(&:display_name).to_sentence) if rest.positive?) ].compact)
    end
  end

  def todo_owners_label(todo)
    owners = todo.owners
    return "Unassigned" if owners.empty?

    ([ "#{owners.first.display_name}#{" (lead)" if owners.size > 1}" ] + owners.drop(1).map(&:display_name)).to_sentence
  end

  def todo_details(todo, with_engagement: false)
    [
      (todo.engagement&.ref if with_engagement),
      (todo.client&.name if with_engagement),
      (l(todo.due_on, format: :short) if todo.due_on),
      ("Internal" unless todo.client_visible?)
    ].compact.join(" · ")
  end

  # Where a piece of work sits, for a card or a row: its engagement's ref, else nothing.
  def todo_ref(todo) = todo.engagement&.ref

  # Its client's name, or that nobody matched (an email from an unknown sender).
  def todo_client_name(todo) = todo.client&.name || "No #{term(:client).downcase} matched"

  # How far a client's request has got, in the portal's words.
  def portal_request_status(todo)
    if todo.request? then "Waiting"
    elsif todo.status == "done" then "Done"
    else "Taken on"
    end
  end
end
