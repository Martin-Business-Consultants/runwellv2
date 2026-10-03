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
end
