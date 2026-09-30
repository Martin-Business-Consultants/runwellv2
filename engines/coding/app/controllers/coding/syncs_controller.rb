# "Sync now": the same catch-up the nightly job runs, on demand.
module Coding
  class SyncsController < ApplicationController
    require_permission :manage_settings
    agent_tool :sync_github, on: :create, title: "Catch up on pull requests, checks and repo access from GitHub now"

    def create
      return redirect_to(coding_settings_path, alert: "Connect to GitHub first.") unless Connection.current&.connected?

      SyncJob.perform_later
      redirect_to coding_settings_path, notice: "Syncing. Refresh in a minute to see the result."
    end
  end
end
