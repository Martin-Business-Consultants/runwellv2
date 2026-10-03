# Close several engagements at once, with one reason for them all.
class Bulk::Engagements::ClosuresController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :close_engagements
  agent_tool :bulk_close_engagements, on: :create, title: "Close several engagements at once", params: { ids: "integer[]!", reason: "string" }

  def create
    apply_to_each(selected(Engagement.all), done: "Closed %{count} #{Setting.current.term(:engagement, count: 2).downcase}", fallback: engagements_path) do |engagement|
      next "it’s already closed" if engagement.closed?

      engagement.close!(reason: params[:reason].presence)
      true
    end
  end
end
