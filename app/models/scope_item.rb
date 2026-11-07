# A section of a piece of work: a part of what it delivers, grouping the work under it. Added,
# renamed, reordered and removed on the work; its state comes from its work.
class ScopeItem < ApplicationRecord
  include LiveRefreshes
  include Noted, Documentable

  belongs_to :work, inverse_of: :scope_items
  has_many :tasks, dependent: :nullify

  delegate :client, :client_id, to: :work
  positioned on: :work

  validates :description, presence: true

  # Delivery state, derived from the work under it.
  def delivery_state = self.class.delivery_state_of(tasks.map(&:status))

  # The same from the statuses of its work alone, for a list that counted them in one query.
  def self.delivery_state_of(statuses)
    return "not_started" if statuses.empty?
    return "done" if statuses.all?("done")
    return "blocked" if statuses.include?("blocked")

    "in_progress"
  end

  def progress = [ tasks.count { |task| task.status == "done" }, tasks.size ]

  private
    def live_streams = [ self, work ]
end
