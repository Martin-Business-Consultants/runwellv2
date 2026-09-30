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
  def delivery_state
    return "not_started" if todos.empty?
    return "done" if todos.all? { |t| t.status == "done" }
    return "blocked" if todos.any? { |t| t.status == "blocked" }

    "in_progress"
  end

  def progress = [ todos.count { |todo| todo.status == "done" }, todos.size ]

  private

  def refuse_if_sent
    if agreement_version.sent?
      errors.add(:base, "items of a sent version are immutable")
      throw :abort
    end
  end
end
