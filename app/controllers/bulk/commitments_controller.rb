# Commitments, many at once: delete open ones (resolved ones stay as history).
class Bulk::CommitmentsController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_delete_commitments, on: :destroy, title: "Delete several open commitments at once", params: { ids: "integer[]!" }

  def destroy
    apply_to_each(selected(Commitment.all), done: "Deleted %{count} commitments", fallback: commitments_path) do |commitment|
      next "it’s resolved, so it stays as history" unless commitment.open?

      commitment.destroy!
      true
    end
  end
end
