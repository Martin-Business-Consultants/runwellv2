class Settings::NamesController < Settings::BaseController
  agent_tool :show_names, on: :show, title: "Show what this install calls things"
  agent_tool :update_names, on: :update, title: "Rename things",
    description: "terminology: { client: { one:, other: }, engagement: {…}, scope_item: {…}, work: {…}, labels: { project: { one:, other:, prefix:, enabled: }, work_order: {…}, service: {…} } }. Send the whole set: anything left out goes back to its default.",
    params: { terminology: {} }

  def show
    @setting = Setting.current
  end

  def update
    Setting.current.update!(terminology: terminology_from(params[:terminology]))
    redirect_to settings_names_path, notice: "Names saved."
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
