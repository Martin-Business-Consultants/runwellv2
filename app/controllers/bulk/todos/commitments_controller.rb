# Several pieces of work made into commitments at once (Todo#convert_to_commitment!): each keeps
# its own date (a week from now without one); ones a plugin keeps something on are skipped.
class Bulk::Todos::CommitmentsController < ApplicationController
  include BulkAction
  allow_staff
  agent_tool :bulk_convert_work_to_commitments, on: :create, title: "Turn several todos into commitments",
    params: { ids: "integer[]!", owner_kind: Commitment::OWNER_KINDS }

  def create
    owner_kind = params[:owner_kind].presence_in(Commitment::OWNER_KINDS) || "us"
    noun = Setting.current.term(:commitment, count: 2).downcase
    apply_to_each(selected(Todo.includes(:owner, engagement: :client)), done: "Made %{count} into #{noun}", fallback: commitments_path) do |todo|
      todo.convert_to_commitment!(owner_kind: owner_kind)
      true
    rescue Todo::ConversionRefused => error
      error.message.sub(/\AIt /, "it ").sub(/\AIt’s/, "it’s")
    end
  end
end
