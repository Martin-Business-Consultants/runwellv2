class Portal::ApprovalsController < Portal::BaseController
  def create
    engagement = client.engagements.find_by_ref!(params[:engagement_ref])
    version = engagement.pending_version
    return redirect_to portal_engagement_path(engagement), alert: "Nothing is awaiting your approval." unless version && current_contact.can_approve?

    name = params[:approver_name].to_s.strip
    return redirect_to portal_engagement_path(engagement), alert: "Please type your name to confirm." if name.blank?

    version.decide!(decision: params.require(:decision), method: "link", contact: current_contact, approver_name: name,
                    comment: params[:comment], ip_address: request.remote_ip, user_agent: request.user_agent, source: "portal")
    redirect_to portal_engagement_path(engagement), notice: "Thank you. Your decision has been recorded."
  end
end
