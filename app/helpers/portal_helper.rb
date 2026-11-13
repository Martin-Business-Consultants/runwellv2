# What the portal's pages share: a task's status and date as a client reads them, the mark on one
# holding a message they haven't read, and the portal's search box.
module PortalHelper
  # The status a client reads (Task#client_status): the team's "in review" and "blocked" stay ours.
  def portal_status_tag(task) = status_tag(task.client_status_label, highlight: task.status == "done" && !task.declined?)

  # A due date, marked when an open task is past it. format: an I18n date format.
  def portal_due(task, format: :short, prefix: nil)
    return unless task.due_on

    tag.span safe_join([ prefix, l(task.due_on, format: format), (tag.span(" · late", class: "portal-due__late") if task.late?) ].compact),
      class: class_names("portal-due", "portal-due--late": task.late?)
  end

  # A dot on a task whose discussion holds something this contact hasn't read. The task's panel
  # takes it off when it opens (portal/tasks/_panel).
  def portal_unread_mark(task)
    return unless portal_unread_task_ids.include?(task.id)

    tag.span class: "portal-unread", data: { unread_task: task.id }, title: "New message", role: "img", aria: { label: "New message" }
  end

  # How far along a piece of work is, from the tasks shared with the client: a bar and "3 of 8".
  def portal_progress(progress)
    return tag.span("—", class: "portal-muted") if progress.nil? || progress[:total].zero?

    tag.span class: "portal-progress" do
      safe_join([ ui(:progress, value: (progress[:done] * 100.0 / progress[:total]).round, size: :sm, class: "portal-progress__bar", aria: { label: "#{progress[:done]} of #{progress[:total]} done" }),
                  tag.span("#{progress[:done]} of #{progress[:total]}", class: "portal-progress__count") ])
    end
  end

  # A list's search box: a plain GET form on ?q=, keeping the page's other choices.
  def portal_search(placeholder)
    form_with url: request.path, method: :get, class: "portal-search", data: { turbo_action: "replace" } do
      safe_join([
        *request.query_parameters.except("q", "page", "task").map { |name, value| hidden_field_tag(name, value, id: nil) },
        ui(:input, name: "q", type: :search, value: params[:q], placeholder: placeholder, class: "portal-search__field", autocomplete: "off", aria: { label: placeholder }),
        (link_to("Clear", url_for(request.query_parameters.except("q", "page")), class: "ui-button", data: { variant: "ghost", size: "sm" }) if params[:q].present?)
      ].compact)
    end
  end

  # A card on a portal page: runeui's card, its title (any markup: a layout's text in template mode)
  # and hint in its header, action: at the header's end. flush: its list or table runs to the
  # card's edges. Other options (the drag-and-drop controller's data) go on the card.
  def portal_card(title: nil, hint: nil, action: nil, flush: false, css: nil, **attrs, &body)
    title = tag.h2(title, class: "portal-card__title") if title.present? && !title.html_safe?
    ui :card, title: title.presence, description: hint.presence, action: action.presence,
      class: class_names("portal-card", css, "portal-card--flush": flush), content: (capture(&body).presence if body), **attrs
  end

  # Who on the team has a task, by name: a client doesn't know our faces.
  def portal_task_people(task) = task.owners.reject(&:agent?).map(&:display_name).to_sentence.presence

  # A browser as a person would name it, from its user agent: "Safari on iPhone".
  def portal_browser_name(user_agent)
    agent = user_agent.to_s
    browser = { "Edg" => "Edge", "OPR" => "Opera", "Firefox" => "Firefox", "Chrome" => "Chrome", "Safari" => "Safari" }.find { |mark, _| agent.include?(mark) }&.last
    device = { "iPhone" => "iPhone", "iPad" => "iPad", "Android" => "Android", "Macintosh" => "Mac", "Windows" => "Windows", "Linux" => "Linux" }.find { |mark, _| agent.include?(mark) }&.last
    [ browser || "A browser", device ].compact.join(" on ")
  end
end
