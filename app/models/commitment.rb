# A promise with an owner and a date, ours or the client's.
class Commitment < ApplicationRecord
  include Eventful, Searchable

  OWNER_KINDS = %w[us client].freeze
  RESOLUTIONS = %w[done missed dropped].freeze

  belongs_to :client
  belongs_to :engagement, optional: true
  belongs_to :user, optional: true
  belongs_to :contact, optional: true

  validates :description, :due_on, :source, presence: true
  validates :owner_kind, inclusion: { in: OWNER_KINDS }
  validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true
  validate :owner_matches_kind

  before_update :refuse_if_resolved

  scope :open, -> { where(resolution: nil) }
  scope :overdue, -> { open.where("due_on < ?", Date.current) }
  scope :due_soon, -> { open.where(due_on: Date.current..(Date.current + 7)) }
  scope :ordered, -> { order(:due_on) }

  def open? = resolution.nil?
  def overdue? = open? && due_on < Date.current

  # One select picks who owns it: "us", "user:3", "client" or "contact:5".
  def owner
    if owner_kind == "us" then user_id ? "user:#{user_id}" : "us"
    else contact_id ? "contact:#{contact_id}" : "client"
    end
  end

  def owner=(key)
    kind, id = key.to_s.split(":", 2)
    self.owner_kind = %w[user us].include?(kind) ? "us" : "client"
    self.user_id = (id if kind == "user")
    self.contact_id = (id if kind == "contact")
  end

  def owner_name
    owner_kind == "us" ? (user&.display_name || "Us") : (contact&.name || client.name)
  end

  def resolve!(resolution, note: nil, actor: Current.user, source: Current.source || "app")
    raise ArgumentError, "already resolved" unless open?

    transaction do
      update!(resolution: resolution, resolved_at: Time.current, resolution_note: note)
      record_event!("commitment.#{resolution}", actor: actor, source: source, payload: { note: note })
    end
  end

  def search_title = description
  def search_content = resolution_note

  private

  def owner_matches_kind
    errors.add(:contact, "must belong to the client") if contact && contact.client_id != client_id
  end

  def refuse_if_resolved
    return if resolution_was.nil?

    raise ActiveRecord::ReadOnlyRecord, "resolved commitments are final"
  end
end
