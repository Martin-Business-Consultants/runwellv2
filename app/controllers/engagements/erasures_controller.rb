# Deleting a closed engagement for good, agreements and decisions included (Engagement#erase!):
# owners only, typing its ref to confirm.
class Engagements::ErasuresController < ApplicationController
  require_permission :erase_engagements
  agent_tool :erase_engagement, on: :create, title: "Delete a closed engagement permanently, with its agreements",
    description: "Only a closed engagement. Removes it with its agreements (sent ones too), the client's decisions, work, commitments, notes, documents and history; the client keeps one event. confirm_ref must be the engagement's ref. Can't be undone: ask the person first.",
    params: { confirm_ref: "string!" }, confirm: "It deletes the engagement and the record of what the client agreed to, for good."

  def create
    engagement = Engagement.find_by_ref!(params[:engagement_ref])
    return redirect_to(engagement, alert: "Close #{engagement.ref} first; only a closed one can be deleted permanently.") unless engagement.closed?
    unless params[:confirm_ref].to_s.strip.casecmp?(engagement.ref)
      return redirect_to(engagement, alert: "Type #{engagement.ref} to confirm deleting it.")
    end

    engagement.erase!
    redirect_to engagement.client, notice: "#{engagement.ref} #{engagement.title} is deleted, with its agreements and history."
  end
end
