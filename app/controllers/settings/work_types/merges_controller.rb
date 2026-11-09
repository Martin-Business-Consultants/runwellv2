# A work type folded into another: its work moves onto that type (refs kept, each recording
# work.retyped) and the type goes. Not for a system type, which is switched off instead.
class Settings::WorkTypes::MergesController < Settings::BaseController
  agent_tool :merge_work_type, on: :create, title: "Merge a work type into another",
    description: "into: the key of the type its work moves to (list_work_types). Each piece of work keeps its ref and records the change in its history; then the merged type is deleted. A system type (project, work order, service) can't be merged: archive it instead.",
    params: { into: "string!" }

  def create
    work_type = WorkType.locate!(params[:work_type_id])
    into = (WorkType.locate!(params[:into]) if params[:into].present?)
    count = work_type.works_count
    work_type.merge_into!(into)
    redirect_to settings_names_path(tab: "types"), notice: "Merged #{work_type.name_one} into #{into.name_one}: moved #{count} #{Setting.current.term(:work, count: count).downcase}, refs kept."
  rescue WorkType::Refused, ActiveRecord::RecordNotFound => error
    redirect_to settings_names_path(tab: "types"), alert: error.message
  end
end
