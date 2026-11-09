# Settings > Names: what the install calls the core things (client, work, section, task). Its
# Types tab is the work types (Settings::WorkTypesController), each a record of its own.
class Settings::NamesController < Settings::BaseController
  agent_tool :show_names, on: :show, title: "Show what this install calls things",
    description: "The words for the core things, and each work type's names and prefix (list_work_types has the rest)."
  agent_tool :update_names, on: :update, title: "Rename things",
    description: "terminology: { client: { one:, other: }, work: {…}, scope_item: {…}, task: {…} }: replaced whole, so anything left out goes back to its default. Work types are renamed with update_work_type.",
    params: { terminology: {} }

  def show
    @setting = Setting.current
    if params[:tab] == "types"
      @work_types = WorkType.ordered.to_a
      counts = Work.group(:label).count
      @work_types.each { it.works_count = counts.fetch(it.key, 0) }
    end
  end

  def update
    kept = Setting.current.terminology.to_h.except(*Setting::TERMS)
    Setting.current.update!(terminology: kept.merge(terminology_from(params[:terminology])))
    redirect_to settings_names_path, notice: "Names saved."
  end

  private

  # Only what differs from a default is kept, so a blank field means "use the default".
  def terminology_from(input)
    input = input&.to_unsafe_h || {}
    Setting::TERMS.to_h { |key| [ key, input.fetch(key, {}).slice("one", "other").compact_blank ] }.compact_blank
  end
end
