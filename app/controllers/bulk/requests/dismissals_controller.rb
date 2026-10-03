# Dismiss several open requests at once, with one reason.
class Bulk::Requests::DismissalsController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :triage_requests
  agent_tool :bulk_dismiss_requests, on: :create, title: "Dismiss several open requests at once", params: { ids: "integer[]!", reason: "string" }

  def create
    reason = params[:reason].presence || "Not needed"
    apply_to_each(selected(Request.all), done: "Dismissed %{count} requests", fallback: requests_path) do |request_record|
      next "it was already triaged" unless request_record.open?

      request_record.dismiss!(reason: reason, actor: current_user)
      true
    end
  end
end
