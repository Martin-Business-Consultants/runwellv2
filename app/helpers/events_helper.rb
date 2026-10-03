module EventsHelper
  def event_title(event) = event.kind.tr("._", "  ").humanize

  # What an event happened to, in words, for the audit log (a person, the install's settings, a
  # client, an engagement by its ref…).
  def audit_subject_name(event)
    subject = event.subject
    case subject
    when nil then "#{event.subject_type} #{event.subject_id} (gone)"
    when Setting then "Settings"
    when Engagement then "#{subject.ref} #{subject.title}"
    else subject.try(:display_name) || subject.try(:name) || subject.try(:title) || subject.try(:subject) || "#{event.subject_type} #{event.subject_id}"
    end
  end

  # The scalar parts of the payload, e.g. "from: planned · to: done".
  def event_details(event)
    (event.payload || {}).filter_map { |key, value| "#{key}: #{value}" if value.present? && !value.is_a?(Enumerable) }.join(" · ")
  end
end
