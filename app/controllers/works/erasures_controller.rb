# Deleting a closed work for good, its work and history included (Work#erase!):
# owners only, typing its ref to confirm.
class Works::ErasuresController < ApplicationController
  require_permission :erase_works
  agent_tool :erase_work, on: :create, title: "Delete a closed work permanently",
    description: "Only a closed work. Removes it with its sections, tasks, notes, documents and history (and whatever plugins keep on it); the client keeps one event. confirm_ref must be the work's ref. Can't be undone: ask the person first.",
    params: { confirm_ref: "string!" }, confirm: "It deletes the work and the record of what the client agreed to, for good."

  def create
    work = Work.find_by_ref!(params[:work_ref])
    return redirect_to(work, alert: "Close #{work.ref} first; only a closed one can be deleted permanently.") unless work.closed?
    unless params[:confirm_ref].to_s.strip.casecmp?(work.ref)
      return redirect_to(work, alert: "Type #{work.ref} to confirm deleting it.")
    end

    work.erase!
    redirect_to work.client, notice: "#{work.ref} #{work.title} is deleted, with its work and history."
  end
end
