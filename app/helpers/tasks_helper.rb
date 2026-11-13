module TasksHelper
  def task_status_options = Task::STATUSES.map { |status| [ status.humanize, status ] }

  # A Tasks list's statuses, for its data-task-list-keeps (Task::List#keeps).
  def task_list_keeps(state) = Task::List.new(kind: "index", state: state).keeps.join(" ")

  def task_owner_options = task_people.map { |user| [ user.display_name, user.id ] }

  # The Tasks page's work filter: only work with open tasks (a large install has
  # hundreds of pieces of work, most with nothing to show here), and the one chosen, whatever it is.
  def task_work_filter_options(current)
    works = Work.where(id: Task.open.select(:work_id)).or(Work.where(ref: current)).order(:ref)
    works.map { |work| [ work.title, work.ref ] }
  end

  # A link that opens a task in the side panel (side-panel controller); its href stays the task's own
  # page, for a new tab or a modifier click. Built here, in Ruby: a data hash worked out in a
  # template (data: some_method) is written by Herb as a literal data="{…}" attribute.
  # A text link is followed by the arrow to the task's page (PeekHelper#page_link_to; open: false
  # leaves it off).
  def side_panel_link_to(task, content = nil, data: {}, open: true, **options, &block)
    data = side_panel_link_data(task, data)
    return link_to(task_path(task), data: data, **options, &block) if block

    with_page_link(link_to(content, task_path(task), data: data, **options), task_path(task), task.title, open)
  end

  # What makes a link open its task in the side panel (side_panel_link_to; a board card's title).
  def side_panel_link_data(task, data = {})
    action = [ data[:action], "side-panel#open" ].compact.join(" ")
    data.merge(turbo_frame: data[:turbo_frame] || "_top", action: action, side_panel_task_param: task.id, turbo_prefetch: false)
  end

  # The team for the inline owner picker, loaded once per page however many rows use it.
  def task_people = @task_people ||= User.active.people.ordered.to_a

  # What a page has once however many rows use it (the pickers' menus): printed at the foot of the
  # page (yield :page_templates in the layout), never inside a row, so removing a row (a task
  # leaving a list) can't take it away from every other row. A side panel loaded on its own (its
  # frame) carries its own; a stream answer needs none, the page has them, except the panel's own
  # copy (panel: true) when the answer redraws the panel. Built only when it's printed (the block).
  def page_template(panel: false, &html)
    if !request.get? || request.format.turbo_stream?
      capture(&html) if panel
    elsif turbo_frame_request_id == "side_panel"
      capture(&html)
    else
      content_for(:page_templates, capture(&html))
      nil
    end
  end

  # The task pickers' menus (status, who's on it, due), on the page once: a row carries only its
  # buttons, each opening the one menu beside itself (data-runeui-open) and saying which task it's
  # for (the picker controller). Without these each row of a long table carried three menus nobody
  # opened. The forms they send are templates the picker copies and points at its task; no token
  # in them: Turbo sends the page's with the submission. The side panel asks for them too
  # (panel: true), so a panel opened over a page with no task rows has its own.
  def task_picker_menus(panel: false)
    return if @task_picker_menus_rendered

    html = page_template(panel: panel) { safe_join([ task_status_menu, task_owner_menu, task_due_menu ]) }
    @task_picker_menus_rendered = true if html || (request.get? && !request.format.turbo_stream?)
    html
  end

  def task_status_menu
    items = Task::STATUSES.map do |status|
      label = safe_join([ tag.span(tag.span(class: "status-dot status-dot--#{status.dasherize}", aria: { hidden: true }), class: "status-dot-picker__dot", data: { picker_part: "dot" }),
        tag.span(status.humanize, class: "picker-menu__label", data: { picker_part: "label" }), icon_tag("check", class: "picker-menu__check") ])
      { label: label, value: status, data: { picker_value: status } }
    end
    ui(:menu, id: "task-status-menu", label: "Status", class: "picker-menu", items: items) +
      tag.template(id: "task-status-form") do
        form_with(url: "#", method: :patch, authenticity_token: false, class: "picker-form") { hidden_field_tag("task[status]", nil, id: nil, data: { picker_field: true }) }
      end
  end

  # The owners picker's people; each click puts that person on the task or takes them off
  # (Tasks::AssignmentsController). Each carries their avatar as the trigger draws it (a
  # <template>), so the picker shows who's on at once, before the answer, and the days they're away
  # in the months around now (Runwell::Plugins.away: time off, holidays), so the picker marks them
  # Out on the task's due date.
  AWAY_WINDOW_BACK = 30
  AWAY_WINDOW_AHEAD = 180

  def task_owner_menu
    away = Runwell::Plugins.away_between((Date.current - AWAY_WINDOW_BACK)..(Date.current + AWAY_WINDOW_AHEAD))
    people = safe_join(task_people.map do |person|
      days = (away.fetch(person.id, Set.new) | away.fetch(:everyone, Set.new)).map(&:iso8601).sort
      ui_tag("ui-combobox-item", { class: "ui-item", value: person.id, label: person.display_name, data: { slot: "combobox-item", picker_value: person.id, picker_away: days.join(" ").presence } }) do
        safe_join([ person_tag(person),
          ui_tag("ui-combobox-item-text", { data: { slot: "combobox-item-text" } }, {}, person.display_name),
          tag.span("Out", class: "owner-picker__away", title: "Away on the day it’s due"),
          ui_tag("ui-combobox-item-indicator", { data: { slot: "combobox-item-indicator" } }, {}, ui_icon(:check)),
          tag.template(person_tag(person), data: { picker_avatar: true }) ])
      end
    end)
    ui(:combobox, id: "task-owner-menu", multiple: true, trigger: false, search: "Who’s on it…", empty: "Nobody by that name.", class: "picker-menu owner-menu", aria: { label: "Who’s on it" }) { people + tag.p("The first on leads.", class: "owner-picker__hint") } +
      tag.template(id: "task-owner-form") do
        form_with(url: "#", method: :post, authenticity_token: false, class: "picker-form") { hidden_field_tag("assignee_id", nil, id: nil, data: { picker_field: true }) }
      end +
      # The avatars as the trigger draws them, for the picker to fill in before the answer.
      tag.template(ui(:avatar_group, people: [], size: :sm, class: "owner-stack", aria: { hidden: true }) + tag.span(class: "owner-stack__more", data: { slot: "avatar-group-count" }), id: "task-owner-stack")
  end

  # A row's due date: a calendar in a popover, with Today and No date under it.
  def task_due_menu
    ui(:popover, id: "task-due-menu", align: :start, class: "picker-menu due-menu", aria: { label: "Due" }) do
      ui(:calendar, id: "task-due-calendar") +
        tag.div(class: "due-menu__foot") do
          ui(:button, content: "Today", variant: :outline, size: :sm, type: :button, data: { picker_set: Date.current.iso8601, picker_today: true }) +
            ui(:button, content: "No date", variant: :ghost, size: :sm, type: :button, data: { picker_set: "" })
        end
    end +
      tag.template(id: "task-due-form") do
        form_with(url: "#", method: :patch, authenticity_token: false, class: "picker-form") { hidden_field_tag("task[due_on]", nil, id: nil, data: { picker_field: true }) + hidden_field_tag(:inline, "panel", id: nil) }
      end
  end

  # Everyone on a task as overlapping avatars (ui :avatar_group), the lead first and on top
  # (preload assignments: :user). hidden: inside a control whose own text names them (the owner
  # picker's trigger), so screen readers don't hear every name twice.
  def task_owners_tag(task, limit: 3, fallback: nil, hidden: false)
    owners = task.owners
    return (fallback ? tag.span(fallback, class: "person__none") : "".html_safe) if owners.empty?

    ui :avatar_group, people: owners.map { { name: it.display_name, src: user_avatar_path(it) } }, max: limit, size: :sm, class: "owner-stack",
      title: (task_owners_label(task) unless hidden), aria: { hidden: (true if hidden) }
  end

  def task_owners_label(task)
    owners = task.owners
    return "Unassigned" if owners.empty?

    ([ "#{owners.first.display_name}#{" (lead)" if owners.size > 1}" ] + owners.drop(1).map(&:display_name)).to_sentence
  end

  def task_details(task, with_work: false)
    [
      (task.work&.title if with_work),
      (task.client&.name if with_work),
      (l(task.due_on, format: :short) if task.due_on),
      ("Internal" unless task.client_visible?)
    ].compact.join(" · ")
  end

  # Where something in Intake came from, in words: "Ted Martin's agent", "Jane Doe via portal",
  # "jo@example.com via email", "Priya via phone".
  def intake_source_label(task)
    return task.agent_name if task.made_by_agent?

    who = task.requester_name || task.created_by&.display_name
    [ who, ("via #{task.source}" if task.source.present?) ].compact.join(" ").presence || "Unknown"
  end

  # One line under a task in the Intake digest (IntakeMailer): who it came from, what it's for and
  # how long it's waited.
  def intake_digest_line(task)
    home = task.work&.title || task.client&.name
    [ intake_source_label(task), ("for #{home}" if home), "came in #{time_ago_in_words(task.intake_at)} ago" ].compact.join(" · ")
  end

  # Intake's Source cell: who it came from as an avatar (the person behind an agent with the AI mark
  # on it), then the channel in a word (AI, Portal, Email, Phone…); the full source in its tooltip.
  def intake_source_tag(task)
    person = task.made_by_agent? ? task.created_by&.agent_owner : (task.contact || task.created_by)
    face = if task.made_by_agent?
      tag.span(class: "agent-actor") { person_tag(person) + icon_tag("ai", class: "agent-actor__mark") }
    elsif person
      person_tag(person)
    else
      avatar(task.requester_name.to_s.presence || "?", size: :md)
    end
    word = task.made_by_agent? ? "AI" : task.source.to_s.humanize
    tag.span(class: "intake-source", title: intake_source_label(task)) { face + tag.span(word, class: "intake-source__word") }
  end

  # The pieces of work a task can be put on (filed from Intake): its client's open work when it has
  # a client, else everyone's grouped by client; the one it's on now whatever its state.
  def task_work_options(task)
    works = Work.open.or(Work.where(id: task.work_id))
    works = works.where(client_id: task.client_id) if task.client_id
    works = works.includes(:client).order(:title).to_a
    return works.map { [ it.title, it.id ] } if task.client_id

    works.group_by(&:client).sort_by { |client, _| client.name.downcase }.map { |client, list| [ client.name, list.map { [ it.title, it.id ] } ] }
  end

  # The AI mark on a task an agent added (Task#made_by_agent?): its icon, naming the agent in its
  # tooltip, or beside it with label: true (the side panel). Nothing for a person's task.
  def agent_made_tag(task, label: nil)
    return unless task.made_by_agent?

    text = "Added by #{task.agent_name}"
    tag.span(class: token_list("agent-made", "agent-made--label": label), title: (text unless label)) do
      safe_join([ icon_tag("ai"), tag.span(text, class: label ? nil : "visually-hidden") ])
    end
  end

  # Where a task sits, for a card or a row: its work's title, else nothing.
  def task_ref(task) = task.work&.title

  # Its client's name, or that nobody matched (an email from an unknown sender).
  def task_client_name(task) = task.client&.name || "No #{term(:client).downcase} matched"

  # How far a client's request has got, in the portal's words.
  def portal_request_status(task)
    if task.declined? then "Declined"
    elsif task.request? then "Waiting"
    elsif task.status == "done" then "Done"
    else "Taken on"
    end
  end
end
