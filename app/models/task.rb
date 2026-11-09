# A task: on a piece of work (often in one of its sections), or straight on a
# client. Small on purpose: who's on it (a lead and others), a status and a date. No time, no money.
# A task nobody has taken on or started is a request (`Task.requests`): what a client asked for by
# email or the portal arrives that way, with who asked (`contact`, or an unmatched sender) and how
# (`source`). A promise with a date is a task with a due date; whoever it's assigned to owns it.
class Task < ApplicationRecord
  include Eventful, Noted, Searchable, Mentions, Documentable, CustomFields, Assignable, Repeats
  include LiveRefreshes, RecordsCreation, ClientPrioritized

  # A request from outside (a client in the portal or through their agent, or an email): set by
  # whoever makes it, so its history says task.requested, credited to who asked, not task.created.
  attr_accessor :requested

  mentionable_fields :description

  # in_review: finished by whoever did it (often an agent), waiting for a person to check and
  # mark it done.
  STATUSES = %w[planned in_progress in_review blocked done].freeze

  belongs_to :work, optional: true
  belongs_to :client, optional: true
  belongs_to :contact, optional: true
  belongs_to :scope_item, optional: true
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  positioned on: [ :work, :status ]
  # The Tasks board's order: one list per status across all work, set by dragging.
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
  # One column of the Tasks board: its tasks in the order dragged, or Done's by when they were due.
  scope :board_column, ->(status) { where(status: status).then { status == "done" ? it.order(:due_on, :position) : it.board_ordered } }
  # When open tasks are due, as the Tasks list's Due filter splits them: late, today, or in
  # the seven days after today.
  scope :due_today, -> { open.where(due_on: Date.current) }
  scope :due_this_week, -> { open.where(due_on: (Date.current + 1)..(Date.current + 7)) }
  # A Tasks section's filter (?tasks= on a piece of work's or a client's page): open by default.
  STATE_FILTERS = %w[open done all].freeze
  def self.state_filter(value) = value.presence_in(STATE_FILTERS) || "open"
  # Those tasks of a scope in a state (open, done, all).
  def self.state_scope(scope, state) = { "open" => scope.open, "done" => scope.where(status: "done") }.fetch(state, scope)
  # The section a piece of work's Tasks show alone (?item=): a section's id, "other" for tasks in
  # none, or nil for all of them.
  def self.section_focus(value) = value == "other" ? "other" : value.presence&.to_i

  DUE_FILTERS = { "overdue" => :overdue, "today" => :due_today, "week" => :due_this_week }.freeze
  # Nobody has taken it on or started it: a request, waiting for someone to be assigned.
  scope :requests, -> { where(owner_id: nil, status: "planned") }

  # Why the status changed, when something other than a person changed it (a client's sunset);
  # kept in the event's payload as reason.
  attr_accessor :status_reason

  after_update_commit :record_status_change, if: :saved_change_to_status?
  before_save :stamp_completion

  # The board's columns, in Fizzy's anatomy: the planned stream, the doing columns, done.
  BOARD_COLUMNS = %w[in_progress in_review blocked].freeze

  def self.filtered(owner: "any", work: "all")
    scope = includes(:owner, :client, { assignments: :user }, :work)
    scope = owner.nil? ? scope.where(owner_id: nil) : scope.assigned_to(owner) unless owner == "any"
    scope = scope.where(work: Work.find_by_ref!(work)) unless work == "all"
    scope
  end

  def request? = owner_id.nil? && status == "planned"

  def requester_name = contact&.name || sender_name.presence || sender_email


  # Moves the task to a status (a board column), and on the board to just before `before` (a
  # task id in that column) or, without one, to the end of it.
  def move!(status:, position: nil, before: nil)
    update!(status: status, position: position || :last, board_position: board_placement(status, before))
  end

  # Its client's ranking (ClientPrioritized): every task shared with them, soonest due unranked.
  def client_priority_peers = Task.client_visible.where(client_id: client_id)
  def client_priority_fallback = [ :due_on, :position, :id ]
  def priority_subject = work || client
  def priority_name = title

  def search_title = title
  def search_content = [ description, sender_name, sender_email ].compact_blank.join(" ")
  def search_client_id = client_id

  private

  def take_client
    self.client_id = work.client_id if work
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
    neighbour = Task.where(status: status).where.not(id: id).find_by(id: before) if before.present?
    neighbour ? { before: neighbour.id } : :last
  end

  def stamp_completion
    self.completed_at = (status == "done" ? (completed_at || Time.current) : nil)
  end

  def record_status_change
    record_event!("task.status", payload: { from: status_before_last_save, to: status, reason: status_reason }.compact)
  end

  ActiveSupport.run_load_hooks(:runwell_task, self)

    def record_creation
      return super unless requested
      return if Current.source == "import"

      asker = [ requester_name, (Current.access_token.name if Current.client_agent?) ].compact.join(" via ")
      record_event!("task.requested", actor: nil, source: source, actor_label: asker)
    end

    def live_streams = [ self, :tasks, work, client, scope_item ]
end
