# "Sync now": the same pull the nightly job runs, on demand.
module Quickbooks
  class SyncsController < ApplicationController
    require_permission :manage_billing
    agent_tool :sync_quickbooks, on: :create, title: "Pull invoices, payments and recurring invoices from QuickBooks now"

    def create
      return redirect_back(fallback_location: quickbooks_settings_path, alert: "Connect QuickBooks first.") unless Connection.ready?

      SyncJob.perform_later
      redirect_back fallback_location: quickbooks_settings_path, notice: "Syncing with QuickBooks. Refresh in a minute."
    end
  end
end
