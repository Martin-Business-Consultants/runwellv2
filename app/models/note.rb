class Note < ApplicationRecord
  include LiveRefreshes

  # Its record's history says a note was added or deleted (and of what kind).
  after_create_commit -> { subject.record_event!("note.added", payload: { kind: kind }) }, if: :subject_records_events?
  # Not when its record is going too: there's no history left to write to.
  after_destroy_commit -> { subject.record_event!("note.deleted", payload: { kind: kind }) }, if: -> { subject_records_events? && !destroyed_by_association }
  include Searchable, Mentions
  # A client's reply on a task tells whoever is on it (Notifier::ClientReplyNotifier).
  include Notifiable

  mentionable_fields :body

  KINDS = %w[call meeting email internal].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :author, class_name: "User", optional: true

  validates :body, :source, presence: true
  validates :kind, inclusion: { in: KINDS }

  before_validation { self.occurred_at ||= Time.current }

  scope :recent, -> { order(occurred_at: :desc) }
  # A task's discussion with the client (client_visible): what the portal shows on it, oldest first.
  scope :client_visible, -> { where(client_visible: true) }
  scope :discussion, -> { client_visible.order(:occurred_at, :id) }

  # Written by the client's own person (a contact), from the portal.
  def from_client? = author&.client?

  # Part of a task's discussion with the client: shared, on a task.
  def discussion? = client_visible? && subject_type == "Task"

  # A notification about it: a client's reply.
  def notification_title = "#{author&.display_name || "A client"} replied"
  def notification_excerpt = ActionController::Base.helpers.strip_tags(body.to_s).squish

  # Its author (or whose agent wrote it), or anyone who may delete records.
  def deletable_by?(user)
    return false unless user

    person_id = user.person.id
    author_id == person_id || (author_id.present? && author&.agent_owner_id == person_id) || user.can?(:delete_records)
  end

  def search_title = "#{kind.humanize} note"
  def search_content = body
  def search_client_id = subject.is_a?(Client) ? subject.id : subject.try(:client_id) || subject.try(:client)&.id

  private
    def subject_records_events? = Current.source != "import" && subject.respond_to?(:record_event!)

    def live_streams = [ subject, subject.try(:work), subject.try(:client) ]

    # Either way a discussion note goes, the other side hears: a client's reply notifies the team
    # (Notifiable), and the team's is emailed to the client's people on the task (PortalMailer).
    def notify_recipients_later
      return unless discussion? && Current.source != "import"

      if from_client?
        super
      else
        subject.reply_contacts(self).each { PortalMailer.with(note: self, contact: it).reply.deliver_later }
      end
    end
end
