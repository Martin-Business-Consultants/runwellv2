module EventsHelper
  def event_title(event) = event.kind.tr("._", "  ").humanize

  # The scalar parts of the payload, e.g. "from: planned · to: done".
  def event_details(event)
    (event.payload || {}).filter_map { |key, value| "#{key}: #{value}" if value.present? && !value.is_a?(Enumerable) }.join(" · ")
  end
end
