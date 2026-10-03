# Engagements, many at once: delete those never sent (the rest are skipped).
class Bulk::EngagementsController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_delete_engagements, on: :destroy, title: "Delete several engagements at once",
    description: "Only engagements never sent to the client are deleted; sent ones are skipped (close them instead).", params: { ids: "integer[]!" }

  def destroy
    apply_to_each(selected(Engagement.all), done: "Deleted %{count} #{Setting.current.term(:engagement, count: 2).downcase}", fallback: engagements_path) do |engagement|
      next "it was sent to the client; close it instead" unless engagement.deletable?

      engagement.destroy!
      true
    end
  end
end
