# A work type dragged into a new place on Settings > Names > Types: before the type it was dropped
# above, or last at the end. The page already shows the new order, so the answer is empty.
class Settings::WorkTypes::PositionsController < Settings::BaseController
  agent_exempt :create, reason: "dragging in the browser; update_work_type sets position"

  def create
    work_type = WorkType.locate!(params[:work_type_id])
    neighbour = WorkType.where.not(id: work_type.id).find_by(key: params[:before])
    work_type.update!(position: neighbour ? { before: neighbour.id } : :last)
    head :no_content
  end
end
