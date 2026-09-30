module AccountManagement
  # A client meeting and the paper around it: the agenda sent at least a day ahead, and the recap
  # (decisions, then action items with owners and dates) sent within a day after. Sending stamps
  # the time, which is what the scorecard counts; a sent agenda or recap never changes. Action
  # items are core commitments, so they show on the client, on home and in the scorecard.
  #
  # Its state is derived: planned, then agenda due (a day or less before the agenda's deadline),
  # then recap due once it has started, then done when the recap is out. Or cancelled.
  class Meeting < ::ApplicationRecord
    include ::Eventful

    RECORD_TYPES = %w[Client Engagement].freeze
    STATES = %w[planned agenda_due recap_due done cancelled].freeze

    belongs_to :client, class_name: "::Client"
    belongs_to :engagement, class_name: "::Engagement", optional: true
    belongs_to :owner, class_name: "::User", optional: true
    belongs_to :created_by, class_name: "::User", optional: true
    has_many :items, class_name: "AccountManagement::MeetingItem", dependent: :destroy
    has_many :commitments, through: :items

    attribute :starts_on, :date
    attribute :starts_at_time, :string

    scope :live, -> { where(cancelled_at: nil) }
    scope :upcoming, -> { live.where(starts_at: Time.current..).order(:starts_at) }
    scope :past, -> { live.where(starts_at: ...Time.current).order(starts_at: :desc) }
    scope :recent, -> { order(starts_at: :desc) }
    scope :needing_agenda, -> { upcoming.where(agenda_sent_at: nil) }
    scope :needing_recap, -> { past.where(recap_sent_at: nil) }

    validates :title, :starts_at, presence: true
    validate :engagement_belongs_to_client
    validate :sent_papers_are_final, on: :update

    before_validation :combine_start
    before_validation :clear_empty_text

    after_initialize :split_start

    def self.for(record)
      case record
      when ::Client then where(client: record)
      when ::Engagement then where(engagement: record)
      else none
      end
    end

    def about=(record)
      if record.is_a?(::Engagement)
        self.engagement = record
        self.client = record.client
      else
        self.client = record
      end
    end

    def state
      if cancelled? then "cancelled"
      elsif recap_sent? then "done"
      elsif started? then "recap_due"
      elsif !agenda_sent? && Time.current >= agenda_due_at - 1.day then "agenda_due"
      else "planned"
      end
    end

    def cancelled? = cancelled_at.present?
    def started? = starts_at <= Time.current
    def agenda_sent? = agenda_sent_at.present?
    def recap_sent? = recap_sent_at.present?

    def agenda_due_at = starts_at - Playbook::AGENDA_AHEAD
    def recap_due_at = starts_at + Playbook::RECAP_WITHIN

    def agenda_late? = !cancelled? && (agenda_sent? ? agenda_sent_at > agenda_due_at : Time.current > agenda_due_at)
    def recap_late? = !cancelled? && (recap_sent? ? recap_sent_at > recap_due_at : Time.current > recap_due_at)

    # Whether each paper went out on time, for the scorecard: nil while it can still make it.
    def agenda_on_time
      return if cancelled?
      return agenda_sent_at <= agenda_due_at if agenda_sent?

      false if Time.current > agenda_due_at
    end

    def recap_on_time
      return if cancelled?
      return recap_sent_at <= recap_due_at if recap_sent?

      false if Time.current > recap_due_at
    end

    # Who it goes to by default: the client's active contacts with an email.
    def recipients = client.contacts.active.where.not(email: [ nil, "" ]).ordered

    # Mark the agenda or recap sent: emailed to contacts from here, or sent another way (a
    # calendar invite, the client's own tool), said in via. Stamps the time, for good.
    def send_agenda!(contacts: [], via: nil, actor: Current.user, source: Current.source)
      send_paper!(:agenda, contacts: contacts, via: via, actor: actor, source: source)
    end

    def send_recap!(contacts: [], via: nil, actor: Current.user, source: Current.source)
      raise ArgumentError, "The meeting hasn’t happened yet: send the recap after it." unless started?

      send_paper!(:recap, contacts: contacts, via: via, actor: actor, source: source)
    end

    def cancel!(actor: Current.user, source: Current.source)
      raise ArgumentError, "Its recap is out; it happened." if recap_sent?

      transaction do
        update_columns(cancelled_at: Time.current, updated_at: Time.current)
        record_event!("meeting.cancelled", actor: actor, source: source || "app")
      end
    end

    def add_action_item!(description:, owner:, due_on:, actor: Current.user, source: Current.source)
      transaction do
        commitment = client.commitments.create!(description: description, owner: owner, due_on: due_on,
          engagement: engagement, source: "meeting: #{title}")
        commitment.record_event!("commitment.added", actor: actor, source: source, payload: { meeting: title })
        items.create!(commitment: commitment)
        commitment
      end
    end

    def when_label = I18n.l(starts_at.in_time_zone, format: :short)
    def label = "#{title}, #{when_label}"

    private
      def send_paper!(paper, contacts:, via:, actor:, source:)
        raise ArgumentError, "It was cancelled." if cancelled?
        raise ArgumentError, "The #{paper} is already out." if public_send(:"#{paper}_sent?")
        raise ArgumentError, "Write the #{paper} first." if public_send(paper).blank?

        contacts = Array(contacts)
        via = contacts.any? ? "email to #{contacts.map(&:name).to_sentence}" : via.presence
        raise ArgumentError, "Choose who it goes to, or say how it was sent." if via.blank?

        transaction do
          update_columns("#{paper}_sent_at": Time.current, "#{paper}_sent_via": via, updated_at: Time.current)
          record_event!("meeting.#{paper}_sent", actor: actor, source: source || "app",
            payload: { via: via, on_time: public_send(:"#{paper}_on_time") })
        end
        contacts.each { MeetingMailer.with(meeting: self, contact: it, paper: paper.to_s).paper.deliver_later }
      end

      def combine_start
        return if starts_on.blank?

        hour, minute = starts_at_time.to_s.split(":").map(&:to_i)
        self.starts_at = Time.zone.local(starts_on.year, starts_on.month, starts_on.day, hour || 9, minute || 0)
      end

      def split_start
        return if starts_at.nil? || starts_on.present?

        self.starts_on = starts_at.to_date
        self.starts_at_time = starts_at.strftime("%H:%M")
      end

      def clear_empty_text
        %i[agenda recap].each { |field| self[field] = nil if ActionController::Base.helpers.strip_tags(self[field].to_s).squish.blank? }
      end

      def engagement_belongs_to_client
        errors.add(:engagement, "must belong to the #{::Client.model_name.human.downcase}") if engagement && engagement.client_id != client_id
      end

      def sent_papers_are_final
        errors.add(:agenda, "was sent and can’t change") if agenda_sent_at_was && will_save_change_to_agenda?
        errors.add(:recap, "was sent and can’t change") if recap_sent_at_was && will_save_change_to_recap?
        errors.add(:starts_at, "can’t move once the agenda is out; cancel it and plan another") if agenda_sent_at_was && will_save_change_to_starts_at?
      end
  end
end
