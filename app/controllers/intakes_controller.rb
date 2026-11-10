# Intake: everything that came in and hasn't been dealt with, newest first: a client's request
# (the portal, an email, a call), a task an agent added, anything nobody has taken on or that isn't
# on a piece of work yet (Task.intake). Someone on it and a piece of work under it, and it leaves.
class IntakesController < ApplicationController
  allow_staff

  NEEDS = %w[any owner work].freeze

  agent_tool :list_intake, on: :show, title: "List intake",
    description: "What came in and hasn't been dealt with: open tasks nobody has taken on, or not on a piece of work yet (requests from clients, emails, tasks agents added), newest first. source: any, clients, agents or team; needs: any, owner (nobody's on it) or work (on no piece of work). Deal with one by update_task: owner_id to take it on, work_id to file it.",
    params: { source: Task::Intake::SOURCES, needs: NEEDS }, next_tools: %i[update_task]

  sortable_columns title: "tasks.title",
    client: [ "clients.name", ->(scope) { scope.left_joins(:client) } ],
    work: [ "works.title", ->(scope) { scope.left_joins(:work) } ],
    came_in: "tasks.created_at"

  def show
    @view = "table"
    @source = params[:source].presence_in(Task::Intake::SOURCES) || "any"
    @needs = params[:needs].presence_in(NEEDS) || "any"

    scope = Task.intake.from_source(@source)
    scope = scope.where(owner_id: nil) if @needs == "owner"
    scope = scope.where(work_id: nil) if @needs == "work"
    scope = scope.includes(:owner, :client, :work, :contact, :custom_values, { assignments: :user }, created_by: :agent_owner).order(created_at: :desc, id: :desc)
    @column_widths = column_widths(scope, :title, :client, :work) if request.format.html?
    @tasks = paginate sorted(scope)
  end
end
