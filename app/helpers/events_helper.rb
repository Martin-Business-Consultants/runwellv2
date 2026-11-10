module EventsHelper
  def event_title(event) = event.kind.tr("._", "  ").humanize

  # What an event happened to, in words, for the audit log (a person, the install's settings, a
  # client, a piece of work by its ref…).
  def audit_subject_name(event)
    subject = event.subject
    case subject
    when nil then "#{event.subject_type} #{event.subject_id} (gone)"
    when Setting then "Settings"
    when Work then subject.title
    else subject.try(:display_name) || subject.try(:name) || subject.try(:title) || subject.try(:subject) || "#{event.subject_type} #{event.subject_id}"
    end
  end

  # The scalar parts of the payload, e.g. "from: planned · to: done".
  def event_details(event)
    (event.payload || {}).filter_map { |key, value| "#{key}: #{value}" if value.present? && !value.is_a?(Enumerable) }.join(" · ")
  end

  # What an event happened to, as a link where it has somewhere to open: a task in the side panel,
  # a client, piece of work or contact as a peek; anything else (or gone) in words.
  def event_subject_link(event)
    subject = event.subject
    name = audit_subject_name(event)
    case subject
    when Task then side_panel_link_to subject, name
    when Client, Work, Contact then peek_link_to subject, name
    else name
    end
  end

  # When, short enough for a narrow column: the time today, else the day and time ("Nov 8, 3:12pm").
  def activity_time(time)
    format = time.to_date == Date.current ? "%-l:%M%P" : (time.year == Date.current.year ? "%b %-d, %-l:%M%P" : "%b %-d, %Y")
    time.strftime(format)
  end

  # AI activity's area filter, in this install's names.
  def agent_activity_area_label(area)
    case area
    when "tasks" then "#{term(:task, count: 2)} and notes"
    when "works" then term(:work, count: 2)
    when "clients" then term(:client, count: 2)
    else "Everything"
    end
  end

  def agent_activity_whose_label(person, whose)
    if whose == "any" then "every agent"
    elsif person.nil? then "nobody's agent"
    elsif person == Current.user&.person then "your agent"
    else person.agent&.display_name || "#{person.display_name}'s agent"
    end
  end

  def agent_activity_empty_text(person, whose)
    if whose == "me" then "Your agent hasn’t done anything in this period. Connect an AI in Settings › Connected apps, and what it does shows here."
    else "Nothing #{agent_activity_whose_label(person, whose)} did in this period."
    end
  end
end
