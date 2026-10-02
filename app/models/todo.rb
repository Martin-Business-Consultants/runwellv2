# A piece of work under an engagement, usually one per approved scope item.
# Small on purpose: an owner, a status and a date. No time, no money.
class Todo < ApplicationRecord
  include Eventful, Noted, Searchable, Mentions, Documentable, CustomFields

  mentionable_fields :description

  # in_review: finished by whoever did it (often an agent), waiting for a person to check and
  # mark it done.
  STATUSES = %w[planned in_progress in_review blocked done].freeze

  belongs_to :engagement
  belongs_to :scope_item, optional: true
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  positioned on: [ :engagement, :status ]
  # The Work board's order: one list per status across every engagement, set by dragging.
  positioned on: :status, column: :board_position

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where.not(status: "done") }
  scope :overdue, -> { open.where("due_on < ?", Date.current) }
  scope :client_visible, -> { where(client_visible: true) }
  scope :board_ordered, -> { order(:board_position) }

  after_update_commit :record_status_change, if: :saved_change_to_status?
  before_save :stamp_completion

  # The board's columns, in Fizzy's anatomy: the planned stream, the doing columns, done.
  BOARD_COLUMNS = %w[in_progress in_review blocked].freeze

  def self.filtered(owner: "any", engagement: "all")
    scope = includes(:owner, engagement: :client)
    scope = scope.where(owner_id: owner) unless owner == "any"
    scope = scope.where(engagement: Engagement.find_by_ref!(engagement)) unless engagement == "all"
    scope
  end

  def client = engagement.client

  # Moves the todo to a status (a board column), and on the board to just before `before` (a
  # todo id in that column) or, without one, to the end of it.
  def move!(status:, position: nil, before: nil)
    update!(status: status, position: position || :last, board_position: board_placement(status, before))
  end

  def search_title = title
  def search_content = description
  def search_client_id = engagement.client_id

  private

  def board_placement(status, before)
    neighbour = Todo.where(status: status).where.not(id: id).find_by(id: before) if before.present?
    neighbour ? { before: neighbour.id } : :last
  end

  def stamp_completion
    self.completed_at = (status == "done" ? (completed_at || Time.current) : nil)
  end

  def record_status_change
    record_event!("todo.status", payload: { from: status_before_last_save, to: status })
  end

  ActiveSupport.run_load_hooks(:runwell_todo, self)
end
