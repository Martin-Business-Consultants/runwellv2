# What happened since an agent last looked: every event (work moved, requests in, agreements sent
# and decided, notes and documents added…) after a cursor, oldest first. A scheduled bot keeps the
# cursor it was given and passes it back next time, so it hears each change once.
class ChangesController < ApplicationController
  allow_staff
  agent_tool :changes, on: :index, title: "What changed since a moment, or since the last call",
    description: "Events oldest first. First call: since (an ISO time, or \"24h\", \"7d\"; default 24h). Then pass back the cursor you were given as after, to hear only what's new. Narrow with client_id (or a client's name) or engagement_ref. Answers up to limit (100, at most 500) with more: true when there are others.",
    params: { since: "string", after: "integer", client_id: "integer", engagement_ref: "string", limit: "integer" }

  MAX = 500

  def index
    request.format = :json
    limit = params[:limit].to_i.clamp(1, MAX).then { params[:limit].present? ? it : 100 }
    scope = Event.order(:id).includes(:subject, :actor_user)
    scope = params[:after].present? ? scope.where("id > ?", params[:after].to_i) : scope.where(occurred_at: since..)

    @client = Client.find(params[:client_id]) if params[:client_id].present?
    @engagement = Engagement.find_by_ref!(params[:engagement_ref]) if params[:engagement_ref].present?
    events = (@client || @engagement) ? scope.limit(MAX * 4).select { within?(it) } : scope.limit(limit + 1).to_a

    @more = events.size > limit
    @events = events.first(limit)
    @cursor = @events.last&.id || params[:after].presence&.to_i || Event.maximum(:id).to_i
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

    # Whether an event is about the client or engagement asked for.
    def within?(event)
      subject = event.subject
      return false unless subject

      engagement = subject.is_a?(Engagement) ? subject : subject.try(:engagement)
      return engagement == @engagement if @engagement

      client_id = subject.is_a?(Client) ? subject.id : subject.try(:client_id) || engagement&.client_id
      client_id == @client.id
    end
end
