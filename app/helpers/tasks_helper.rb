module TasksHelper
  def task_status_options = Task::STATUSES.map { |status| [ status.humanize, status ] }

  def task_owner_options = User.active.people.ordered.map { |user| [ user.display_name, user.id ] }

  # The Work page's work filter: only work with open tasks (a large install has
  # hundreds of pieces of work, most with nothing to show here), and the one chosen, whatever it is.
  def task_work_filter_options(current)
    works = Work.where(id: Task.open.select(:work_id)).or(Work.where(ref: current)).order(:ref)
    works.map { |work| [ "#{work.ref} #{work.title}", work.ref ] }
  end

  # A link that opens a task in the side panel (side-panel controller); its href stays the task's own
  # page, for a new tab or a modifier click. Built here, in Ruby: a data hash worked out in a
  # template (data: some_method) is written by Herb as a literal data="{…}" attribute.
  def side_panel_link_to(task, content = nil, data: {}, **options, &block)
    action = [ data[:action], "side-panel#open" ].compact.join(" ")
    data = data.merge(turbo_frame: data[:turbo_frame] || "_top", action: action, side_panel_task_param: task.id)
    block ? link_to(task_path(task), data: data, **options, &block) : link_to(content, task_path(task), data: data, **options)
  end

  # The team for the inline owner picker, loaded once per page however many rows use it.
  def task_people = @task_people ||= User.active.people.ordered.to_a

  # The status picker's choices, on the page once like the owner picker's.
  def task_status_options_template
    return if @task_status_options_rendered

    @task_status_options_rendered = true
    tag.template(id: "task-status-options") do
      safe_join(Task::STATUSES.map do |status|
        tag.li(class: "popup__item", role: "checkbox", aria: { checked: false }, data: { picker_value: status }) do
          tag.button(type: "submit", name: "task[status]", value: status, class: "popup__btn", data: { action: "picker#choose" }) do
            safe_join([ tag.span(tag.span(class: "status-dot status-dot--#{status.dasherize}", aria: { hidden: true }), class: "status-dot-picker__dot", data: { picker_part: "dot" }),
              tag.span(status.humanize, class: "popup__label", data: { picker_part: "label" }),
              icon_tag("check", class: "checked") ])
          end
        end
      end)
    end
  end

  # The owners picker's people, on the page once like the others; each click puts that person on
  # the work or takes them off (Tasks::AssignmentsController).
  def task_assignee_options_template
    return if @task_assignee_options_rendered

    @task_assignee_options_rendered = true
    tag.template(id: "task-assignee-options") do
      safe_join(task_people.map do |person|
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
  def task_owners_tag(task, limit: 3, fallback: nil, hidden: false)
    owners = task.owners
    return (fallback ? tag.span(fallback, class: "person__none") : "".html_safe) if owners.empty?

    shown = owners.first(limit)
    rest = owners.size - shown.size
    tag.span class: "avatar-stack owner-stack", title: (task_owners_label(task) unless hidden), aria: { hidden: (true if hidden) } do
      safe_join(shown.map { person_tag(it) } +
        [ (tag.span("+#{rest}", class: "avatar avatar--md avatar--more", title: owners.drop(limit).map(&:display_name).to_sentence) if rest.positive?) ].compact)
    end
  end

  def task_owners_label(task)
    owners = task.owners
    return "Unassigned" if owners.empty?

    ([ "#{owners.first.display_name}#{" (lead)" if owners.size > 1}" ] + owners.drop(1).map(&:display_name)).to_sentence
  end

  def task_details(task, with_work: false)
    [
      (task.work&.ref if with_work),
      (task.client&.name if with_work),
      (l(task.due_on, format: :short) if task.due_on),
      ("Internal" unless task.client_visible?)
    ].compact.join(" · ")
  end

  # Where a piece of work sits, for a card or a row: its work's ref, else nothing.
  def task_ref(task) = task.work&.ref

  # Its client's name, or that nobody matched (an email from an unknown sender).
  def task_client_name(task) = task.client&.name || "No #{term(:client).downcase} matched"

  # How far a client's request has got, in the portal's words.
  def portal_request_status(task)
    if task.request? then "Waiting"
    elsif task.status == "done" then "Done"
    else "Taken on"
    end
  end
end
