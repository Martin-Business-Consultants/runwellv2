# "Sync now": the same pull the nightly job runs, on demand.
module GoogleAds
  class SyncsController < ApplicationController
    require_permission :manage_settings
    agent_tool :sync_google_ads, on: :create, title: "Pull the latest Google Ads figures now"

    def create
      return redirect_to(google_ads_settings_path, alert: "Connect to Google Ads first.") unless Connection.current&.connected?

      SyncJob.perform_later
      redirect_to google_ads_settings_path, notice: "Syncing. Refresh in a minute to see the result."
    end
  end
end
