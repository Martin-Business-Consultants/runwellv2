# A piece of work: under an engagement (often in one of its sections), or straight on a
# client. Small on purpose: who's on it (a lead and others), a status and a date. No time, no money.
# Work nobody has taken on or started is a request (`Todo.requests`): what a client asked for by
# email or the portal arrives that way, with who asked (`contact`, or an unmatched sender) and how
# (`source`). A promise with a date is work with a due date; whoever it's assigned to owns it.
class Todo < ApplicationRecord
  include Eventful, Noted, Searchable, Mentions, Documentable, CustomFields, Assignable
  include LiveRefreshes

  mentionable_fields :description

  # in_review: finished by whoever did it (often an agent), waiting for a person to check and
  # mark it done.
  STATUSES = %w[planned in_progress in_review blocked done].freeze

  belongs_to :engagement, optional: true
  belongs_to :client, optional: true
  belongs_to :contact, optional: true
  belongs_to :scope_item, optional: true
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  positioned on: [ :engagement, :status ]
  # The Work board's order: one list per status across every engagement, set by dragging.
  positioned on: :status, column: :board_position

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, presence: true
  validate :client_matches

  before_validation :take_client
  before_validation :match_sender

  scope :open, -> { where.not(status: "done") }
  scope :overdue, -> { open.where("due_on < ?", Date.current) }
  scope :client_visible, -> { where(client_visible: true) }
  scope :board_ordered, -> { order(:board_position) }
  scope :due_soon, -> { open.where(due_on: Date.current..(Date.current + 7)) }
  # When open work is due, as home and the Work list's Due filter split it: late, today, or in
  # the seven days after today.
  scope :due_today, -> { open.where(due_on: Date.current) }
  scope :due_this_week, -> { open.where(due_on: (Date.current + 1)..(Date.current + 7)) }
  DUE_FILTERS = { "overdue" => :overdue, "today" => :due_today, "week" => :due_this_week }.freeze
  # Nobody has taken it on or started it: a request, waiting for someone to be assigned.
  scope :requests, -> { where(owner_id: nil, status: "planned") }

  after_update_commit :record_status_change, if: :saved_change_to_status?
  before_save :stamp_completion

  # The board's columns, in Fizzy's anatomy: the planned stream, the doing columns, done.
  BOARD_COLUMNS = %w[in_progress in_review blocked].freeze

  def self.filtered(owner: "any", engagement: "all")
    scope = includes(:owner, :client, { assignments: :user }, :engagement)
    scope = owner.nil? ? scope.where(owner_id: nil) : scope.assigned_to(owner) unless owner == "any"
    scope = scope.where(engagement: Engagement.find_by_ref!(engagement)) unless engagement == "all"
    scope
  end

  def request? = owner_id.nil? && status == "planned"

  def requester_name = contact&.name || sender_name.presence || sender_email


  # Moves the todo to a status (a board column), and on the board to just before `before` (a
  # todo id in that column) or, without one, to the end of it.
  def move!(status:, position: nil, before: nil)
    update!(status: status, position: position || :last, board_position: board_placement(status, before))
  end

  def search_title = title
  def search_content = [ description, sender_name, sender_email ].compact_blank.join(" ")
  def search_client_id = client_id

  private

  def take_client
    self.client_id = engagement.client_id if engagement
  end

  def match_sender
    return if contact || sender_email.blank?

    self.contact = Contact.find_by(email: sender_email.strip.downcase)
    self.client ||= contact&.client
  end

  def client_matches
    errors.add(:contact, "must belong to the #{Setting.current.term(:client).downcase}") if contact && client_id && contact.client_id != client_id
  end

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

    def live_streams = [ self, :work, engagement, client, scope_item ]
end
