# Resolve several commitments at once: done, missed or dropped.
class Bulk::Commitments::ResolutionsController < ApplicationController
  include BulkAction
  allow_staff
  agent_tool :bulk_resolve_commitments, on: :create, title: "Resolve several commitments at once",
    params: { ids: "integer[]!", resolution: Commitment::RESOLUTIONS }

  def create
    resolution = params[:resolution].presence_in(Commitment::RESOLUTIONS) || "done"
    apply_to_each(selected(Commitment.all), done: "Marked %{count} commitments #{resolution}", fallback: commitments_path) do |commitment|
      next "it’s already resolved" unless commitment.open?

      commitment.resolve!(resolution)
      true
    end
  end
end
