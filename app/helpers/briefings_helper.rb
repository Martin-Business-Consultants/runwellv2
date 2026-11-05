module BriefingsHelper
  # How many of each section home shows; the rest are a link away (briefing_more_path).
  def briefing_shown = 8

  # Where a section's whole list is: the person's work, filtered the same way.
  def briefing_more_path(key)
    case key
    when "overdue", "today", "week" then todos_path(owner: "me", due: key, view: "table", sort: "due")
    when "in_progress", "in_review", "blocked" then todos_path(owner: "me", status: key, view: "table")
    when "review" then todos_path(owner: "me", status: "in_review", view: "table")
    when "mentions" then notifications_path
    end
  end

  # The line at the top of home: each count that isn't zero, linking to its list.
  def briefing_summary(briefing)
    parts = { "overdue" => "overdue", "today" => "due today", "week" => "this week", "review" => "in review", "blocked" => "blocked", "mentions" => "unread mentions" }
    links = parts.filter_map do |key, words|
      count = briefing.count(key)
      link_to("#{count} #{words}", briefing_more_path(key), class: class_names("home-summary__item", "home-summary__item--late": key == "overdue")) if count.positive?
    end
    safe_join(links, tag.span(" · ", class: "txt-subtle", aria: { hidden: true }))
  end

  # The greeting at the top of home, by the time of day in the install's zone.
  def briefing_greeting(user)
    part = case Time.current.hour
    when 5..11 then "Good morning"
    when 12..17 then "Good afternoon"
    else "Good evening"
    end
    name = user&.person&.first_name
    name.present? ? "#{part}, #{name}" : part
  end

  # Home's summary cards (shadcn's dashboard SectionCards): the counts that matter most, each
  # linking to its list. Waiting on you adds up everything in the side column.
  def briefing_stats(briefing)
    waiting = briefing.waiting_sections.sum(&:count)
    [
      { key: "overdue", label: "Overdue", count: briefing.count("overdue"), icon: "bell-alert", alert: briefing.count("overdue").positive?,
        note: briefing.count("overdue").positive? ? "Past their due date" : "Nothing late", path: briefing_more_path("overdue") },
      { key: "today", label: "Due today", count: briefing.count("today"), icon: "check-circle", note: "Yours to finish today", path: briefing_more_path("today") },
      { key: "week", label: "This week", count: briefing.count("week"), icon: "history", note: "Due in the next seven days", path: briefing_more_path("week") },
      { key: "waiting", label: "Waiting on you", count: waiting, icon: "bell", note: briefing_waiting_note(briefing),
        path: briefing.count("mentions").positive? ? notifications_path : briefing_more_path("review") }
    ]
  end

  def briefing_waiting_note(briefing)
    parts = { "review" => "in review", "blocked" => "blocked", "mentions" => nil }.filter_map do |key, words|
      count = briefing.count(key)
      next unless count.positive?

      words ? "#{count} #{words}" : pluralize(count, "mention")
    end
    parts.any? ? parts.join(" · ") : "Reviews, blocks and mentions"
  end

  # When something is due, the way a person says it: "today", "tomorrow", "Friday", "Oct 20", or
  # "3 days late".
  def home_due(date)
    days = (date - Date.current).to_i
    if days.negative? then "#{pluralize(-days, "day")} late"
    elsif days.zero? then "today"
    elsif days == 1 then "tomorrow"
    elsif days < 7 then date.strftime("%A")
    else l(date, format: :short)
    end
  end

  # Where a piece of work belongs, in a few words: the client, then the engagement's ref.
  def home_work_where(todo)
    [ todo.client&.name, todo.engagement&.ref ].compact.join(" · ")
  end
end
