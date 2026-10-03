# Requests, many at once: delete open ones (triaged ones stay as history).
class Bulk::RequestsController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_delete_requests, on: :destroy, title: "Delete several open requests at once", params: { ids: "integer[]!" }

  def destroy
    apply_to_each(selected(Request.all), done: "Deleted %{count} requests", fallback: requests_path) do |request_record|
      next "it was triaged, so it stays as history" unless request_record.open?

      request_record.destroy!
      true
    end
  end
end
