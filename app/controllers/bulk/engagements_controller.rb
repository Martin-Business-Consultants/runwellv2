# Engagements, many at once: delete those with no work yet (the rest are skipped).
class Bulk::EngagementsController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_delete_engagements, on: :destroy, title: "Delete several engagements at once",
    description: "Only engagements with no work yet are deleted; the rest are skipped (close them instead).", params: { ids: "integer[]!" }

  def destroy
    apply_to_each(selected(Engagement.all), done: "Deleted %{count} #{Setting.current.term(:engagement, count: 2).downcase}", fallback: engagements_path) do |engagement|
      next "it has work on it; close it instead" unless engagement.deletable?

      engagement.destroy!
      true
    end
  end
end
