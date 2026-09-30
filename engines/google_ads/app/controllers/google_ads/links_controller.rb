# Pointing an engagement at a Google Ads account, or letting go of it.
module GoogleAds
  class LinksController < ApplicationController
    require_permission :link_ad_accounts
    agent_tool :link_ad_account, on: :create, title: "Link a Google Ads account to an engagement",
      params: { link: { customer_id: "string!" } }, confirm: "The client will see that account’s spend and results in their portal."
    agent_tool :unlink_ad_account, on: :destroy, title: "Unlink an engagement’s Google Ads account"

    before_action :set_engagement

    def create
      link = @engagement.build_google_ads_link(customer_id: params.expect(link: :customer_id)[:customer_id], linked_by: current_user)
      if link.save
        @engagement.record_event!("google_ads.linked", payload: { customer_id: link.customer_id })
        SyncJob.perform_later if Connection.current&.connected?
        redirect_to engagement_path(@engagement), notice: "Linked Google Ads account #{link.formatted_customer_id}."
      else
        redirect_to engagement_path(@engagement), alert: link.errors.full_messages.to_sentence
      end
    end

    def destroy
      link = @engagement.google_ads_link or return redirect_to(engagement_path(@engagement))
      link.destroy!
      @engagement.record_event!("google_ads.unlinked", payload: { customer_id: link.customer_id })
      redirect_to engagement_path(@engagement), notice: "Unlinked the Google Ads account. Its history stays until another engagement stops using it."
    end

    private
      def set_engagement = @engagement = ::Engagement.find_by!(ref: params[:engagement_ref].to_s.upcase)
  end
end
