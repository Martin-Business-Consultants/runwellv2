class ScopeItem < ApplicationRecord
  include Noted, Documentable

  belongs_to :agreement_version, inverse_of: :scope_items
  has_many :todos, dependent: :nullify

  delegate :engagement, to: :agreement_version
  delegate :client, :client_id, to: :engagement
  positioned on: :agreement_version

  validates :description, presence: true
  validates :price_cents, numericality: { only_integer: true }

  before_save :refuse_if_sent
  before_destroy :refuse_if_sent

  # Delivery state, derived from the work under it.
  def delivery_state = self.class.delivery_state_of(todos.map(&:status))

  # The same from the statuses of its work alone, for a list that counted them in one query.
  def self.delivery_state_of(statuses)
    return "not_started" if statuses.empty?
    return "done" if statuses.all?("done")
    return "blocked" if statuses.include?("blocked")

    "in_progress"
  end

  def progress = [ todos.count { |todo| todo.status == "done" }, todos.size ]

  private

  def refuse_if_sent
    if agreement_version.sent? && !Current.erasing
      errors.add(:base, "items of a sent version are immutable")
      throw :abort
    end
  end
end
