# A section of an engagement: a part of what it delivers, grouping the work under it. Added,
# renamed, reordered and removed on the engagement; its state comes from its work.
class ScopeItem < ApplicationRecord
  include Noted, Documentable

  belongs_to :engagement, inverse_of: :scope_items
  has_many :todos, dependent: :nullify

  delegate :client, :client_id, to: :engagement
  positioned on: :engagement

  validates :description, presence: true

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
end
