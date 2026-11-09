# Close several works at once, with one reason for them all.
class Bulk::Works::ClosuresController < ApplicationController
  include BulkAction
  allow_staff
  require_permission :close_works
  agent_tool :bulk_close_works, on: :create, title: "Mark several works complete (or cancelled) at once",
    params: { ids: "integer[]!", outcome: Work::CLOSE_OUTCOMES, reason: "string" }

  def create
    apply_to_each(selected(Work.all), done: "#{(params[:outcome].presence_in(Work::CLOSE_OUTCOMES) || "completed").capitalize} %{count} #{Setting.current.term(:work, count: 2).downcase}", fallback: works_path) do |work|
      next "it’s already #{work.state_label.downcase}" unless work.closable?

      work.close!(reason: params[:reason].presence, outcome: params[:outcome])
      true
    end
  end
end
