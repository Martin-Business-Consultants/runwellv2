# The client's approval page, reached from the emailed link. GET shows the
# snapshot; the decision happens only on POST with a typed name.
class ApprovalsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :verify_authenticity_token, only: :create
  before_action :set_link
  around_action { |_, action| @link.contact.client.in_time_zone(&action) }

  layout "public"

  def show
    @link.opened!
    @version = @link.agreement_version
  end

  def create
    return redirect_to approval_path(@link), alert: "This link is no longer valid." unless @link.usable?

    name = params[:approver_name].to_s.strip
    return redirect_to approval_path(@link), alert: "Please type your name to confirm." if name.blank?

    @link.agreement_version.decide!(decision: params.require(:decision), method: "link", contact: @link.contact,
                                    approver_name: name, approver_email: @link.contact.email, comment: params[:comment],
                                    ip_address: request.remote_ip, user_agent: request.user_agent, source: "approval link")
    redirect_to approval_path(@link), notice: "Thank you. Your decision has been recorded."
  rescue ArgumentError => e
    redirect_to approval_path(@link), alert: e.message
  end

  private

  def set_link = @link = ApprovalLink.find_by!(token: params[:token])
end
