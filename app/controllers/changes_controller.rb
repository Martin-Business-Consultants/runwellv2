# What happened since an agent last looked: every event (work moved, requests in, work closed
# and decided, notes and documents added…) after a cursor, oldest first. A scheduled bot keeps the
# cursor it was given and passes it back next time, so it hears each change once.
class ChangesController < ApplicationController
  allow_staff
  agent_tool :changes, on: :index, title: "What changed since a moment, or since the last call",
    description: "Events oldest first. First call: since (an ISO time, or \"24h\", \"7d\"; default 24h). Then pass back the cursor you were given as after, to hear only what's new. Narrow with client_id (or a client's name) or work_ref. Answers up to limit (100, at most 500) with more: true when there are others.",
    params: { since: "string", after: "integer", client_id: "integer", work_ref: "string", limit: "integer" }

  MAX = 500

  def index
    request.format = :json
    limit = params[:limit].to_i.clamp(1, MAX).then { params[:limit].present? ? it : 100 }
    scope = Event.where.not(subject_type: Event::SECURITY_SUBJECTS).order(:id).includes(:subject, :actor_user)
    scope = params[:after].present? ? scope.where("id > ?", params[:after].to_i) : scope.where(occurred_at: since..)

    @client = Client.find(params[:client_id]) if params[:client_id].present?
    @work = Work.find_by_ref!(params[:work_ref]) if params[:work_ref].present?
    if @client || @work
      changes_within(scope, limit)
    else
      events = scope.limit(limit + 1).to_a
      @more = events.size > limit
      @events = events.first(limit)
      @cursor = @events.last&.id || params[:after].presence&.to_i || Event.maximum(:id).to_i
    end
  end

  private
    def since
      case params[:since].to_s.strip
      when /\A(\d+)\s*h\z/i then $1.to_i.hours.ago
      when /\A(\d+)\s*d\z/i then $1.to_i.days.ago
      when "" then 24.hours.ago
      else Time.zone.parse(params[:since]) || raise(ActionController::BadRequest, "since should be an ISO time, or like 24h or 7d")
      end
    end

    # For one client or piece of work: a window of events, kept if they're about it (a plugin's
    # subjects too, so the match is in Ruby). The cursor moves past everything looked at, matched
    # or not, so events about others never hold it back; more says there's more to look through.
    def changes_within(scope, limit)
      window = MAX * 4
      scanned = scope.limit(window).to_a
      ActiveRecord::Associations::Preloader.new(records: scanned.map(&:subject).grep(Task), associations: :work).call
      matched = scanned.select { within?(it) }

      if matched.size > limit
        @events, @more = matched.first(limit), true
        @cursor = @events.last.id
      else
        @events, @more = matched, scanned.size == window
        @cursor = scanned.last&.id || params[:after].presence&.to_i || Event.maximum(:id).to_i
      end
    end

    # Whether an event is about the client or work asked for.
    def within?(event)
      subject = event.subject
      return false unless subject

      work = subject.is_a?(Work) ? subject : subject.try(:work)
      return work == @work if @work

      client_id = subject.is_a?(Client) ? subject.id : subject.try(:client_id) || work&.client_id
      client_id == @client.id
    end
end
