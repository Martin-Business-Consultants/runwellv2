class Portal::EngagementsController < Portal::BaseController
  agent_tool :portal_engagements, on: :index, title: "Your engagements",
    description: "Every engagement with you: its ref (like WO-12), title and state (active or closed)."
  agent_tool :portal_engagement, on: :show, title: "One engagement: its parts, the work, and its documents",
    description: "Give its ref (WO-12) or title. Its sections and how each is going, the work shared with you, and its documents.",
    next_tools: %i[portal_send_request]

  def index
    @engagements = client.engagements.ordered.includes(:client)
  end

  def show
    @engagement = client.engagements.includes(scope_items: :todos).find_by_ref!(params[:ref])
  end
end
