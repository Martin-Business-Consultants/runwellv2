# Intake: everything that came in and hasn't been decided, newest first (Task::Intake): a client's
# request (the portal, an email, a call), a task an agent added, anything made without an owner or a
# piece of work. Accepting or declining it takes it out.
class IntakesController < ApplicationController
  allow_staff

  NEEDS = %w[any owner work].freeze

  agent_tool :list_intake, on: :show, title: "List intake",
    description: "What came in and hasn't been decided: tasks made without an owner or a piece of work (requests from clients, emails, tasks agents added), newest first, until someone accepts or declines them. source: any, clients, agents or team; needs: any, owner (nobody's on it) or work (on no piece of work). Decide with accept_task or decline_task; update_task with work_id files one.",
    params: { source: Task::Intake::SOURCES, needs: NEEDS }, next_tools: %i[accept_task decline_task]

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
