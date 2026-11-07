# Works, many at once: delete those with no work yet (the rest are skipped).
class Bulk::WorksController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :bulk_delete_works, on: :destroy, title: "Delete several works at once",
    description: "Only work with no tasks yet is deleted; the rest are skipped (close them instead).", params: { ids: "integer[]!" }

  def destroy
    apply_to_each(selected(Work.all), done: "Deleted %{count} #{Setting.current.term(:work, count: 2).downcase}", fallback: works_path) do |work|
      next "it has #{Setting.current.term(:task, count: 2).downcase} on it; close it instead" unless work.deletable?

      work.destroy!
      true
    end
  end
end
