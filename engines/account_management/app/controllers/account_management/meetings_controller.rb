# Client meetings: the agenda before, the recap after, and the action items that come out of them.
module AccountManagement
  class MeetingsController < ApplicationController
    allow_staff
    agent_tool :list_meetings, on: :index, title: "List client meetings",
      params: { state: %w[upcoming due past all], client_id: "integer", owner: %w[anyone me] }
    agent_tool :create_meeting, on: :create, title: "Plan a client meeting",
      description: "record: \"Type:id\" for a Client or Engagement. starts_on and starts_at_time (24h, \"14:30\") are when it starts, in the agency's time zone (the client's own zone is only for what they see). owner_id: who runs it (defaults to the client's lead, then you). Write the agenda now or later; it goes out at least a day ahead.",
      params: { record: "string!", meeting: { title: "string!", starts_on: "date!", starts_at_time: "string", owner_id: "integer", agenda: "text" } },
      next_tools: %i[send_meeting_agenda]
    agent_tool :show_meeting, on: :show, title: "Show a client meeting",
      description: "Its agenda and recap, when each was sent and whether on time, and its action items (commitments)."
    agent_tool :update_meeting, on: :update, title: "Change a client meeting",
      description: "A sent agenda or recap never changes, and the time can't move once the agenda is out.",
      params: { meeting: { title: "string", starts_on: "date", starts_at_time: "string", owner_id: "integer", agenda: "text", recap: "text" } }
    agent_tool :send_meeting_agenda, on: :send_agenda, title: "Send a meeting’s agenda",
      description: "contact_ids: the client's contacts to email it to. Or, sent another way (a calendar invite), leave them out and say how in via. Stamps when it went out, for good.",
      params: { contact_ids: [ "integer" ], via: "string" }, confirm: "With contacts, it emails them the agenda. Either way the agenda is final once sent."
    agent_tool :send_meeting_recap, on: :send_recap, title: "Send a meeting’s recap",
      description: "After the meeting: the decisions in the recap, with its action items listed. contact_ids to email it, or via for another way. Add action items first with add_meeting_action_item.",
      params: { contact_ids: [ "integer" ], via: "string" }, confirm: "With contacts, it emails them the recap and its action items. Either way the recap is final once sent."
    agent_tool :cancel_meeting, on: :cancel, title: "Cancel a client meeting"
    agent_tool :delete_meeting, on: :destroy, title: "Delete a meeting planned by mistake", description: "Only before its agenda goes out."
    require_permission :delete_records, only: :destroy

    before_action :set_meeting, except: %i[index new create]

    def index
      @view = index_view
      @state = params[:state].presence_in(%w[upcoming due past all]) || "upcoming"
      @owner = params[:owner].presence_in(%w[anyone me]) || "anyone"

      scope = case @state
      when "upcoming" then Meeting.upcoming
      when "past" then Meeting.past
      when "due" then Meeting.live.where(id: Meeting.needing_agenda.select(:id)).or(Meeting.live.where(id: Meeting.needing_recap.select(:id))).order(:starts_at)
      else Meeting.recent
      end
      scope = scope.where(owner: Current.user) if @owner == "me"
      scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
      @meetings = paginate scope.includes(:client, :engagement, :owner)
    end

    def show
    end

    def new
      record = QuickAction.locate(params[:record], Meeting::RECORD_TYPES) if params[:record].present?
      record ||= ::Client.find_by(id: params[:client_id])
      @meeting = Meeting.new(starts_on: Date.tomorrow, starts_at_time: "10:00")
      @meeting.about = record if record
    end

    def create
      record = QuickAction.locate(params[:record], QuickAction::RECORD_TYPES) if params[:record].present?
      record = record.try(:engagement) || record.try(:client) unless record.nil? || Meeting::RECORD_TYPES.include?(record.class.name)
      @meeting = Meeting.new(meeting_params.merge(created_by: Current.user))
      @meeting.about = record if record
      @meeting.owner ||= @meeting.client&.account_lead&.user || Current.user

      if @meeting.client.nil?
        redirect_back fallback_location: account_management_meetings_path, alert: "Choose the #{helpers.term(:client).downcase} or #{helpers.term(:engagement).downcase} it’s with."
      elsif @meeting.save
        @meeting.record_event!("meeting.planned", payload: { starts_at: @meeting.starts_at.iso8601 })
        redirect_to account_management_meeting_path(@meeting), notice: "Planned #{@meeting.title} for #{@meeting.when_label}. Send the agenda by #{l @meeting.agenda_due_at, format: :short}."
      else
        redirect_back fallback_location: account_management_meetings_path, alert: @meeting.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      if @meeting.update(meeting_params)
        redirect_to account_management_meeting_path(@meeting), notice: "Saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def send_agenda = send_paper(:agenda)
    def send_recap = send_paper(:recap)

    def cancel
      @meeting.cancel!
      redirect_to account_management_meeting_path(@meeting), notice: "Cancelled."
    rescue ArgumentError => e
      redirect_to account_management_meeting_path(@meeting), alert: e.message
    end

    def destroy
      return redirect_to(account_management_meeting_path(@meeting), alert: "Its agenda went out, so it’s part of the record: cancel it instead.") if @meeting.agenda_sent?

      @meeting.destroy!
      redirect_to account_management_meetings_path, notice: "Deleted the meeting."
    end

    private
      def set_meeting = @meeting = Meeting.find(params[:id])

      def send_paper(paper)
        contacts = @meeting.client.contacts.active.where(id: Array(params[:contact_ids]).compact_blank).to_a
        @meeting.public_send(:"send_#{paper}!", contacts: contacts, via: params[:via])
        late = !@meeting.public_send(:"#{paper}_on_time")
        redirect_to account_management_meeting_path(@meeting),
          notice: "#{paper.to_s.capitalize} sent#{" to #{contacts.map(&:name).to_sentence}" if contacts.any?}#{late ? ", late" : ""}."
      rescue ArgumentError => e
        redirect_to account_management_meeting_path(@meeting), alert: e.message
      end

      def meeting_params
        attributes = params.expect(meeting: %i[title starts_on starts_at_time owner_id agenda recap])
        attributes[:owner] = ::User.active.people.find_by(id: attributes.delete(:owner_id)) if attributes.key?(:owner_id)
        attributes
      end
  end
end
