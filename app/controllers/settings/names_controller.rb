class Settings::NamesController < Settings::BaseController
  agent_tool :show_names, on: :show, title: "Show what this install calls things"
  agent_tool :update_names, on: :update, title: "Rename things",
    description: "terminology: { client: { one:, other: }, engagement: {…}, scope_item: {…}, work: {…}, labels: { project: { one:, other:, prefix:, enabled: }, work_order: {…}, service: {…} } }. Send the names (client, engagement, scope_item, work), the labels, or both: whichever part is sent is replaced whole (anything left out of it goes back to its default), and a part not sent stays as it was.",
    params: { terminology: {} }

  def show
    @setting = Setting.current
  end

  def update
    input = params[:terminology]&.to_unsafe_h || {}
    # Each tab sends its own part (the things, or the types); the part not sent stays as it was.
    kept = Setting.current.terminology.to_h
    kept = kept.except(*Setting::TERMS) if input.keys.intersect?(Setting::TERMS)
    kept = kept.except("labels") if input.key?("labels")
    Setting.current.update!(terminology: kept.merge(terminology_from(params[:terminology])))
    redirect_to settings_names_path(tab: ("types" if input.key?("labels"))), notice: "Names saved."
  end

  private

  # Only what differs from a default is kept, so a blank field means "use the default".
  def terminology_from(input)
    input = input&.to_unsafe_h || {}
    terms = Setting::TERMS.to_h { |key| [ key, input.fetch(key, {}).slice("one", "other").compact_blank ] }.compact_blank
    labels = Engagement::LABELS.to_h do |label|
      fields = input.dig("labels", label) || {}
      entry = fields.slice("one", "other", "prefix").compact_blank
      entry["prefix"] = entry["prefix"].upcase.gsub(/[^A-Z0-9]/, "") if entry["prefix"]
      entry["enabled"] = false if fields["enabled"] == "0"
      [ label, entry ]
    end.compact_blank
    labels.any? ? terms.merge("labels" => labels) : terms
  end
end
