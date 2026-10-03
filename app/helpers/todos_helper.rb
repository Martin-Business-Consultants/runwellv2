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

  # The owner picker's choices, on the page once (the first picker renders it); each picker copies
  # them into its menu when it opens (picker#fill), where they submit that picker's form.
  def todo_owner_options_template
    return if @todo_owner_options_rendered

    @todo_owner_options_rendered = true
    choices = [ [ "", tag.span(icon_tag("person"), class: "owner-picker__empty owner-picker__empty--small", aria: { hidden: true }), "Unassigned", tag.span(icon_tag("person-add"), class: "owner-picker__empty", aria: { hidden: true }) ] ] +
      todo_people.map { |person| [ person.id.to_s, avatar_image_tag(person, class: "owner-picker__avatar owner-picker__avatar--small", alt: ""), person.display_name, avatar_image_tag(person, class: "owner-picker__avatar", alt: "") ] }

    tag.template(id: "todo-owner-options") do
      safe_join(choices.map do |value, icon, name, avatar|
        tag.li(class: "popup__item", role: "checkbox", aria: { checked: false }, data: { filter_target: "item", picker_value: value }) do
          tag.button(type: "submit", name: "todo[owner_id]", value: value, class: "btn popup__btn full-width", data: { action: "picker#choose" }) do
            safe_join([ icon, tag.span(name, class: "overflow-ellipsis flex-item-grow", data: { picker_part: "name" }),
              icon_tag("check", class: "checked flex-item-justify-end"), tag.span(avatar, hidden: true, data: { picker_part: "avatar" }) ])
          end
        end
      end)
    end
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
