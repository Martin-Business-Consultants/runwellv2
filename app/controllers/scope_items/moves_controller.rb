# A section of a piece of work dragged to a new place among the others on its Tasks tab (the core's
# drag-and-drop: before is the section it now sits above, blank for the end). The page refreshes
# in place, its sidebar's list of sections with it.
class ScopeItems::MovesController < ApplicationController
  allow_staff
  agent_exempt :create, reason: "dragging a section on a piece of work's Tasks tab; update_scope_item sets its position"

  def create
    item = ScopeItem.find(params[:scope_item_id])
    before = item.work.scope_items.where.not(id: item.id).find_by(id: params[:before]) if params[:before].present?
    item.update!(position: before ? { before: before.id } : :last)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
      format.html { redirect_to work_path(item.work, tab: "tasks"), notice: "#{item.description} moved." }
    end
  end
end
