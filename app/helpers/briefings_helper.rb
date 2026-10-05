module BriefingsHelper
  def question_subject_label(subject)
    subject.is_a?(Engagement) ? "#{subject.ref} #{subject.title}" : subject.name
  end

  # How many of each section home shows; the rest are a link away (briefing_more_path).
  def briefing_shown = 8

  # Where a section's whole list is.
  def briefing_more_path(key)
    case key
    when "requests" then requests_path
    when "awaiting_client" then engagements_path(state: "sent")
    when "drafts" then engagements_path(state: "draft")
    when "waiting_on_them", "you_promised" then commitments_path
    when "review", "blocked" then todos_path(view: "board")
    when "overdue_todos" then todos_path(view: "table", sort: "due")
    end
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

  # A note's subject in a few words, for the discussion on home.
  def home_subject_label(subject)
    case subject
    when Engagement then subject.ref
    when Todo then subject.title
    when Request then subject.subject
    else subject.try(:name) || subject.try(:description) || subject.model_name.human
    end
  end
end
