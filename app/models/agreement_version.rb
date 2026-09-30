# Exactly what the client saw. Draft until sent; frozen after, so the approval
# always refers to a fixed snapshot with a hash.
class AgreementVersion < ApplicationRecord
  include Eventful, Mentions
  include Lifecycle

  mentionable_fields :reason

  KINDS = %w[initial change_order revision add_on].freeze
  CADENCES = %w[weekly monthly quarterly].freeze

  belongs_to :engagement, inverse_of: :agreement_versions
  belongs_to :sent_by, class_name: "User", optional: true
  belongs_to :superseded_by, class_name: "AgreementVersion", optional: true
  has_many :scope_items, -> { order(:position) }, dependent: :destroy, inverse_of: :agreement_version
  has_one :approval, dependent: :destroy
  has_many :approval_links, dependent: :destroy
  has_many :todos, through: :scope_items

  validates :kind, inclusion: { in: KINDS }
  validates :cadence, inclusion: { in: CADENCES }, allow_nil: true
  validates :number, presence: true

  before_update :freeze_if_sent
  # Prepended so it runs before the dependent associations try to destroy
  # their rows and the version's own message is the one that surfaces.
  before_destroy :refuse_destroy_if_sent, prepend: true

  def draft? = sent_at.nil?
  def sent? = sent_at.present?
  def approved? = approval&.decision == "approved"
  def changes_requested? = approval&.decision == "changes_requested"
  def awaiting_decision? = sent? && approval.nil? && superseded_by_id.nil?
  def initial? = kind == "initial"

  # Total this version puts in front of the client. A change order's items are
  # its delta; an initial version's items are the whole price.
  def items_total_cents = scope_items.sum(&:price_cents)

  def label
    initial? ? "Agreement" : "#{kind.humanize} ##{number}"
  end

  def status
    if draft? then "draft"
    elsif approved? then "approved"
    elsif changes_requested? then "changes_requested"
    elsif awaiting_decision? then "awaiting_decision"
    else "superseded"
    end
  end

  private

  FROZEN_EXCEPTIONS = %w[superseded_by_id updated_at].freeze

  def freeze_if_sent
    return if sent_at_was.nil?

    illegal = changes.keys - FROZEN_EXCEPTIONS
    raise ActiveRecord::ReadOnlyRecord, "sent agreement versions are immutable (#{illegal.join(', ')})" if illegal.any?
  end

  def refuse_destroy_if_sent
    if sent?
      errors.add(:base, "sent agreement versions cannot be deleted")
      throw :abort
    end
  end
end
