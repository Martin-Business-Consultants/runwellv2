# A client ordering the tasks shared with them by what matters most to them: on Tasks, or within a
# section on a piece of work's page. One order for all of them (ClientPrioritized), so a move in
# either place shows in both.
class Portal::Tasks::PrioritiesController < Portal::BaseController
  include PortalPrioritizing

  agent_tool :portal_prioritize_task, on: :create, title: "Put a task in order of priority",
    description: "Moves one of the tasks shared with you just before `before` (another of them, by id) on your priorities, or to the end without it. The team sees your order.",
    params: { before: "integer" }

  def create
    tasks = current_contact.portal_tasks
    task = tasks.find(params[:task_id])
    before = tasks.find_by(id: params[:before]) if params[:before].present?
    prioritize(task, before)
  end
end
