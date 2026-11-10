require "csv"

# Settings > Audit log, for owners: every event in the install, newest first, from sign-ins and
# security changes to work and tasks, filtered by area, person and period, and downloadable
# as CSV for whoever keeps the records.
class Settings::AuditLogsController < Settings::BaseController
  AREAS = {
    "all" => "Everything",
    "security" => "Sign-in and settings",
    "works" => :work,
    "tasks" => :task,
    "requests" => "Requests",
    "clients" => :client
  }.freeze
  PERIODS = { "7" => "Last 7 days", "30" => "Last 30 days", "90" => "Last 90 days", "all" => "All time" }.freeze
  CSV_LIMIT = 50_000

  agent_tool :audit_log, on: :show, title: "Read the audit log",
    description: "Every event (sign-ins, security and settings changes, work, tasks, requests), newest first. area: #{AREAS.keys.join(", ")}; person: a user id; days: 7, 30, 90 or all.",
    params: { area: AREAS.keys, person: "integer", days: PERIODS.keys }

  # An area's label, in this install's names (Settings > Names).
  def self.area_label(key)
    label = AREAS.fetch(key)
    return label if label.is_a?(String)
    name = Setting.current.term(label, count: 2)
    label == :task ? "#{name} and notes" : name
  end

  def show
    @view = "table"
    @area = params[:area].presence_in(AREAS.keys) || "all"
    @days = params[:days].presence_in(PERIODS.keys) || "30"
    @person = User.find_by(id: params[:person]) if params[:person].present?
    scope = filtered(Event.recent.includes(:actor_user, :subject))

    respond_to do |format|
      format.html { @events = paginate(scope) }
      format.json { @events = scope.limit(500) }
      format.csv { send_data csv(scope.limit(CSV_LIMIT)), filename: "audit-log-#{Date.current}.csv", type: "text/csv" }
    end
  end

  private
    def filtered(scope)
      scope = scope.where(occurred_at: @days.to_i.days.ago..) unless @days == "all"
      scope = scope.where(actor_user: [ @person, @person.agent ].compact) if @person
      scope.in_area(@area)
    end

    def csv(events)
      CSV.generate do |csv|
        csv << %w[when kind by via source subject_type subject_id subject details]
        events.each do |event|
          csv << [ event.occurred_at.utc.iso8601, event.kind, event.actor_name, (event.actor if event.source == "agent"), event.source,
                   event.subject_type, event.subject_id, helpers.audit_subject_name(event), helpers.event_details(event) ]
        end
      end
    end
end
