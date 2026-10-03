class Portal::EngagementsController < Portal::BaseController
  agent_tool :portal_engagements, on: :index, title: "Your engagements with the agency",
    description: "Every engagement the agency has with you: its ref (like WO-12), title, state, and whether an agreement is waiting for your decision."
  agent_tool :portal_engagement, on: :show, title: "One engagement: what was agreed, the work, and anything awaiting you",
    description: "Give its ref (WO-12) or title. The scope in force, the agreement waiting for your decision (exactly as it was sent), past agreements and decisions, the work shared with you, and its documents.",
    next_tools: %i[portal_decide portal_send_request]

  def index
    @engagements = client.engagements.ordered.includes(agreement_versions: [ :approval, :scope_items ])
  end

  def show
    @engagement = client.engagements.find_by_ref!(params[:ref])
    @pending = @engagement.pending_version
  end
end
