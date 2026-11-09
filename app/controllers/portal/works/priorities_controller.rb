# A client ordering their pieces of work by what matters most to them (Your work, dragged).
class Portal::Works::PrioritiesController < Portal::BaseController
  include PortalPrioritizing

  agent_tool :portal_prioritize_work, on: :create, title: "Put a piece of your work in order of priority",
    description: "Moves it just before `before` (another of your works' refs, or its title) on your list of priorities, or to the end without it. The team sees your order.",
    params: { before: "string" }

  def create
    works = client.works
    work = works.find_by_ref!(params[:work_ref])
    before = works.find_by(ref: params[:before].to_s.upcase) || works.find_by(title: params[:before]) if params[:before].present?
    prioritize(work, before)
  end
end
