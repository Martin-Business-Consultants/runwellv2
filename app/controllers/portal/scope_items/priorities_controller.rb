# A client ordering a piece of work's sections by what matters most to them (its page, dragged).
class Portal::ScopeItems::PrioritiesController < Portal::BaseController
  include PortalPrioritizing

  agent_tool :portal_prioritize_section, on: :create, title: "Put a section of your work in order of priority",
    description: "Moves the section (its id, from portal_work) just before `before` (another section of the same work) on your priorities, or to the end without it. The team sees your order.",
    params: { before: "integer" }

  def create
    item = ScopeItem.where(work: current_contact.portal_works).find(params[:scope_item_id])
    before = item.work.scope_items.find_by(id: params[:before]) if params[:before].present?
    # The work's tasks, grouped by section in this order, follow it.
    prioritize(item, before, refresh: true)
  end
end
