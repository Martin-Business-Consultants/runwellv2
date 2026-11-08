class Note < ApplicationRecord
  include LiveRefreshes

  # Its record's history says a note was added or deleted (and of what kind).
  after_create_commit -> { subject.record_event!("note.added", payload: { kind: kind }) }, if: :subject_records_events?
  after_destroy_commit -> { subject.record_event!("note.deleted", payload: { kind: kind }) }, if: :subject_records_events?
  include Searchable, Mentions

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

  # Its author (or the author's person, for a note an agent wrote), or anyone who may delete records.
  def deletable_by?(user)
    return false unless user

    author_id == user.id || (author&.agent_owner_id.present? && author.agent_owner_id == user.id) || user.can?(:delete_records)
  end

  def search_title = "#{kind.humanize} note"
  def search_content = body
  def search_client_id = subject.is_a?(Client) ? subject.id : subject.try(:client_id) || subject.try(:client)&.id

  private
    def subject_records_events? = Current.source != "import" && subject.respond_to?(:record_event!)

    def live_streams = [ subject, subject.try(:work), subject.try(:client) ]
end
