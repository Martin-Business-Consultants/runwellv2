# Settings > Names > Types: the kinds of work an install runs (WorkType). Added, changed, switched
# off (archived) and back on, merged into another, reordered and, while nothing uses them, deleted.
# Project, work order and service are the system types: renamed, re-prefixed or switched off, never
# deleted or merged. The page is the Types tab of Names; every answer goes back there.
class Settings::WorkTypesController < Settings::BaseController
  PARAMS = [ :name_one, :name_other, :prefix, :description, :shape, :cadence, :check_in, :starting_sections, :position, { starting_sections: [] } ].freeze

  agent_tool :list_work_types, on: :index, title: "List work types",
    description: "The kinds of work this install runs, in order: each one's key (what create_work's label takes), names, ref prefix, how its work runs (shape fixed or recurring, cadence, a check-in each period), the sections new work starts with, whether it's a system type (project, work order, service: never deleted) or archived (not offered for new work), and how many pieces of work use it."
  agent_tool :create_work_type, on: :create, title: "Add a work type",
    description: "name_one / name_other: what one and several are called (the plural defaults from the name). prefix: what its refs start with (up to 4 letters or digits, not another type's). shape: fixed (delivered, then closed) or recurring (runs until stopped), with cadence (#{Cadence::KEYS.join(", ")}) and check_in (a task repeating each period to look back on it) for recurring. starting_sections: the sections new work of the type starts with. Its key comes from the name and never changes.",
    params: { work_type: { name_one: "string!", name_other: "string", prefix: "string!", description: "string", shape: WorkType::SHAPES.keys, cadence: Cadence::KEYS, check_in: "boolean", starting_sections: "string[]" } }
  agent_tool :update_work_type, on: :update, title: "Change a work type",
    description: "Rename it, give it another prefix (new refs only: refs already given keep theirs), change how its new work runs or the sections it starts with, or move it (position, 1 is first). Work already started keeps its own shape and cadence.",
    params: { work_type: { name_one: "string", name_other: "string", prefix: "string", description: "string", shape: WorkType::SHAPES.keys, cadence: Cadence::KEYS, check_in: "boolean", starting_sections: "string[]", position: "integer" } }
  agent_tool :delete_work_type, on: :destroy, title: "Delete a work type",
    description: "Only a type you added that no work uses. One in use is archived (archive_work_type) or merged into another (merge_work_type); a system type (project, work order, service) can only be archived."

  before_action :set_work_type, only: %i[update destroy]

  def index
    @work_types = WorkType.ordered.to_a
    counts = Work.group(:label).count
    @work_types.each { it.works_count = counts.fetch(it.key, 0) }
    respond_to do |format|
      format.html { redirect_to settings_names_path(tab: "types") }
      format.json
    end
  end

  def create
    work_type = WorkType.new(work_type_params)
    if work_type.save
      redirect_to types_page, notice: "Added #{work_type.name_one}: its refs start #{work_type.prefix}-."
    else
      redirect_to types_page, alert: work_type.errors.full_messages.to_sentence
    end
  end

  def update
    if @work_type.update(work_type_params)
      redirect_to types_page, notice: "Saved #{@work_type.name_one}."
    else
      redirect_to types_page, alert: @work_type.errors.full_messages.to_sentence
    end
  end

  def destroy
    @work_type.destroy_unused!
    redirect_to types_page, notice: "Deleted #{@work_type.name_one}."
  rescue WorkType::Refused => error
    redirect_to types_page, alert: error.message
  end

  private
    def set_work_type = @work_type = WorkType.locate!(params[:id])
    def work_type_params = params.expect(work_type: PARAMS)
    def types_page = settings_names_path(tab: "types")
end
