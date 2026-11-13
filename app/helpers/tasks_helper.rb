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
    action = [ data[:action], "side-panel#open" ].compact.join(" ")
    data = data.merge(turbo_frame: data[:turbo_frame] || "_top", action: action, side_panel_task_param: task.id, side_panel_title_param: task.title, turbo_prefetch: false)
    return link_to(task_path(task), data: data, **options, &block) if block

    with_page_link(link_to(content, task_path(task), data: data, **options), task_path(task), task.title, open)
  end

  # The team for the inline owner picker, loaded once per page however many rows use it.
  def task_people = @task_people ||= User.active.people.ordered.to_a

  # The status picker's choices, on the page once like the owner picker's.
  # A <template> a row's menu copies from (picker#fill): printed once, at the foot of the page
  # (yield :page_templates in the layout), never inside a row or a panel, so removing a row (a task
  # leaving a list) or closing the panel can't take it away from every other menu. A side panel
  # loaded on its own (its frame) carries its own; a stream answer needs none, the page has them.
  def page_template(html)
    return html if turbo_frame_request_id == "side_panel"
    return if request.format.turbo_stream?

    content_for(:page_templates, html)
    nil
  end

  def task_status_options_template
    return if @task_status_options_rendered

    @task_status_options_rendered = true
    html = tag.template(id: "task-status-options") do
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
    page_template(html)
  end

  # The status and owner menus' insides, on the page once like their choices: a row carries only
  # its button and an empty <dialog>, and the picker copies this in the first time it opens,
  # pointing the form at that task (picker controller, url value). Without these each row of a
  # long table carried two dialogs' worth of forms nobody opened. No per-form token: the form's
  # address is filled in later, and Turbo sends the page's token with the submission.
  def task_status_popup_template
    return if @task_status_popup_rendered

    @task_status_popup_rendered = true
    html = tag.template(id: "task-status-popup") do
      safe_join([ tag.strong("Status", class: "popup__title"),
        form_with(url: "#", method: :patch, authenticity_token: false, data: { picker_target: "form" }) do
          tag.ul(class: "popup__list", role: "group", data: { picker_target: "list" })
        end ])
    end
    page_template(html)
  end

  def task_owner_popup_template
    return if @task_owner_popup_rendered

    @task_owner_popup_rendered = true
    html = tag.template(id: "task-owner-popup") do
      safe_join([
        tag.input(type: "search", class: "owner-picker__search", placeholder: "Who’s on it…", autocomplete: "off", aria: { label: "Find a person" },
          data: { "1p-ignore": "true", filter_target: "input", dialog_target: "focusMouse", action: "input->filter#filter" }),
        form_with(url: "#", method: :post, authenticity_token: false, data: { picker_target: "form" }) do
          tag.ul(class: "popup__list", role: "group", data: { picker_target: "list" })
        end,
        tag.p("The first on leads.", class: "owner-picker__hint") ])
    end
    page_template(html)
  end

  # The owners picker's people, on the page once like the others; each click puts that person on
  # the task or takes them off (Tasks::AssignmentsController). Each carries their avatar as the
  # trigger draws it (a <template>), so the picker shows who's on at once, before the answer, and
  # the days they're away in the months around now (Runwell::Plugins.away: time off, holidays), so
  # the picker marks them Out on the task's due date.
  AWAY_WINDOW_BACK = 30
  AWAY_WINDOW_AHEAD = 180

  def task_assignee_options_template
    return if @task_assignee_options_rendered

    @task_assignee_options_rendered = true
    away = Runwell::Plugins.away_between((Date.current - AWAY_WINDOW_BACK)..(Date.current + AWAY_WINDOW_AHEAD))
    html = tag.template(id: "task-assignee-options") do
      safe_join(task_people.map do |person|
        days = (away.fetch(person.id, Set.new) | away.fetch(:everyone, Set.new)).map(&:iso8601).sort
        tag.li(class: "popup__item", role: "checkbox", aria: { checked: false }, data: { filter_target: "item", picker_value: person.id, picker_away: days.join(" ").presence }) do
          tag.button(type: "submit", name: "assignee_id", value: person.id, class: "popup__btn", data: { action: "picker#choose" }) do
            safe_join([ avatar_image_tag(person, class: "avatar owner-picker__avatar", alt: ""),
              tag.span(person.display_name, class: "popup__label"),
              tag.span("Out", class: "owner-picker__away", title: "Away on the day it’s due"),
              icon_tag("check", class: "checked") ])
          end +
          tag.template(person_tag(person), data: { picker_avatar: true })
        end
      end)
    end
    page_template(html)
  end

  # Everyone on a task as overlapping avatars (rune_ui's avatar stack), the lead first and
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
