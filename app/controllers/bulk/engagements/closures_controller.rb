# Close several engagements at once, with one reason for them all.
class Bulk::Engagements::ClosuresController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :close_engagements
  agent_tool :bulk_close_engagements, on: :create, title: "Mark several engagements complete (or cancelled) at once",
    params: { ids: "integer[]!", outcome: Engagement::CLOSE_OUTCOMES, reason: "string" }

  def create
    apply_to_each(selected(Engagement.all), done: "#{(params[:outcome].presence_in(Engagement::CLOSE_OUTCOMES) || "completed").capitalize} %{count} #{Setting.current.term(:engagement, count: 2).downcase}", fallback: engagements_path) do |engagement|
      next "it’s already closed" if engagement.closed?

      engagement.close!(reason: params[:reason].presence, outcome: params[:outcome])
      true
    end
  end
end
