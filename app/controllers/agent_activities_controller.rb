# AI activity: everything agents did (User::Agent, someone's AI acting through a token): the tasks
# they added, the changes they made, the notes they left, newest first. Your own agent's by
# default, or a teammate's, or everyone's. Sign-ins and settings stay in the audit log.
class AgentActivitiesController < ApplicationController
  allow_staff

  AREAS = %w[all tasks works clients].freeze
  PERIODS = { "1" => "Today and yesterday", "7" => "Last 7 days", "30" => "Last 30 days", "all" => "All time" }.freeze

  agent_tool :agent_activity, on: :show, title: "What agents did",
    description: "Everything people's agents did (tasks added, changes, notes, closes), newest first. whose: me (the person you act for, the default), any (everyone's agents), or a person's id or name; area: #{AREAS.join(", ")}; days: #{PERIODS.keys.join(", ")} (7 by default).",
    params: { whose: "string", area: AREAS, days: PERIODS.keys }

  def show
    @view = "table"
    @whose = params[:whose].presence || "me"
    @area = params[:area].presence_in(AREAS) || "all"
    @days = params[:days].presence_in(PERIODS.keys) || "7"
    @person = whose_person

    scope = Event.by_agents.where.not(subject_type: Event::SECURITY_SUBJECTS).in_area(@area)
      .includes(actor_user: :agent_owner).preload(:subject).recent
    scope = scope.where(occurred_at: @days.to_i.days.ago.beginning_of_day..) unless @days == "all"
    scope = scope.by_agent_of(@person) if @whose != "any"

    respond_to do |format|
      format.html { @events = paginate(scope) }
      format.json { @events = scope.limit(500) }
    end
  end

  private
    # The person whose agent it is: you, or the one picked (by id or name); nil for everyone's or
    # a name that matches nobody (the list is then empty, since a filter never errors).
    def whose_person
      return if @whose == "any"

      id = User.owner_id_for(@whose, me: current_user.person)
      User.people.find_by(id: id)
    rescue Agent::Resolver::Ambiguous => ambiguous
      ambiguous.candidates.first
    rescue Agent::Resolver::Missing
      nil
    end
end
