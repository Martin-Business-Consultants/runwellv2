# A work type switched off (archived: not offered for new work; work of the type keeps it) or back
# on. The system types too: an install that never runs work orders switches them off.
class Settings::WorkTypes::ArchivesController < Settings::BaseController
  agent_tool :archive_work_type, on: :create, title: "Switch off a work type",
    description: "Archived: no longer offered when starting work. Work of the type keeps it, and restore_work_type switches it back on."
  agent_tool :restore_work_type, on: :destroy, title: "Switch a work type back on",
    description: "Offered again when starting work."

  before_action { @work_type = WorkType.locate!(params[:work_type_id]) }

  def create
    @work_type.archive!
    redirect_to settings_names_path(tab: "types"), notice: "#{@work_type.name_one} switched off: no longer offered for new #{Setting.current.term(:work, count: 2).downcase}. What’s already started keeps it."
  end

  def destroy
    @work_type.restore!
    redirect_to settings_names_path(tab: "types"), notice: "#{@work_type.name_one} is on again."
  end
end
