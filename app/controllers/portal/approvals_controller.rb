class Portal::ApprovalsController < Portal::BaseController
  agent_tool :portal_decide, on: :create, title: "Decide on the agreement awaiting you",
    description: "Approve, or ask for changes to, the agreement portal_engagement shows as awaiting your decision. Only a contact who can approve may; approver_name is the person's own typed name, which is recorded with the time and that their agent did it. Show them the agreement first.",
    params: { decision: Approval::DECISIONS.map { it.to_s }, approver_name: "string!", comment: "text" },
    confirm: "This records the client's decision on the agreement, binding as if they clicked it themselves."

  def create
    engagement = client.engagements.find_by_ref!(params[:engagement_ref])
    version = engagement.pending_version
    return redirect_to portal_engagement_path(engagement), alert: "Nothing is awaiting your approval." unless version && current_contact.can_approve?
    if Current.client_agent? && !Setting.current.client_agent_approvals?
      return redirect_to portal_engagement_path(engagement), alert: "#{Setting.current.brand_name} asks for agreements to be decided in the portal itself, not by an agent."
    end

    name = params[:approver_name].to_s.strip
    return redirect_to portal_engagement_path(engagement), alert: "Please type your name to confirm." if name.blank?

    version.decide!(decision: params.require(:decision), method: Current.client_agent? ? "agent" : "link", contact: current_contact, approver_name: name,
                    comment: params[:comment], ip_address: request.remote_ip, user_agent: agent_or_browser, source: Current.client_agent? ? "agent" : "portal")
    redirect_to portal_engagement_path(engagement), notice: "Thank you. Your decision has been recorded."
  end

  private
    # How the decision was made, kept with it: the browser, or the agent and the app it used.
    def agent_or_browser = Current.client_agent? ? "#{current_contact.name}'s agent via #{Current.access_token.name}" : request.user_agent
end
