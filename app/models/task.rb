# A task: on a piece of work (often in one of its sections), or straight on a
# client. Small on purpose: who's on it (a lead and others), a status and a date. No time, no money.
# A task nobody has taken on or started is a request (`Task.requests`): what a client asked for by
# email or the portal arrives that way, with who asked (`contact`, or an unmatched sender) and how
# (`source`). A promise with a date is a task with a due date; whoever it's assigned to owns it.
class Task < ApplicationRecord
  include Eventful, Noted, Searchable, Mentions, Documentable, CustomFields, Assignable, Repeats
  include LiveRefreshes, RecordsCreation, ClientPrioritized, TextFilterable, RemovesLater, Discussion
  # A request from outside tells the people who take requests on (Notifier::RequestNotifier).
  include Notifiable

  # A request from outside (a client in the portal or through their agent, or an email): set by
  # whoever makes it, so its history says task.requested, credited to who asked, not task.created.
  attr_accessor :requested

  mentionable_fields :description
  filters_text_on "tasks.title", "works.title", "works.ref", "clients.name", "tasks.sender_name", "tasks.sender_email", joins: %i[work client]

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
  before_validation :drop_section_from_other_work, if: :will_save_change_to_work_id?
  after_update :record_filing, if: :saved_change_to_work_id?

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

  # Who added it, as Tasks filters it: anyone, people, or agents (User::Agent: AI acting for a person).
  MADE_BY = %w[any people agents].freeze

  scope :made_by_agents, -> { where(created_by_id: User.agents.select(:id)) }
  scope :made_by_people, -> { where(created_by_id: nil).or(where.not(created_by_id: User.agents.select(:id))) }

  def self.filtered(owner: "any", work: "all", made_by: "any")
    scope = includes(:owner, :client, { assignments: :user }, :work)
    scope = owner.nil? ? scope.where(owner_id: nil) : scope.assigned_to(owner) unless owner == "any"
    scope = scope.where(work: Work.find_by_ref!(work)) unless work == "all"
    scope = scope.public_send("made_by_#{made_by}") unless made_by == "any"
    scope
  end

  # Intake: what came in and hasn't been dealt with, an open task that nobody has taken on or that
  # isn't on a piece of work yet (a request from a client, an email, a task an agent added).
  # Someone on it and a piece of work under it, and it's left intake.
  scope :intake, -> { open.where(owner_id: nil).or(open.where(work_id: nil)) }
  def intake? = status != "done" && (owner_id.nil? || work_id.nil?)

  # Where it came from, as Intake filters it: a client (a contact, or an email's sender), an agent,
  # or someone on the team.
  INTAKE_SOURCES = %w[any clients agents team].freeze
  scope :from_clients, -> { where("tasks.contact_id IS NOT NULL OR COALESCE(tasks.sender_email, '') <> ''") }
  scope :from_team, -> { made_by_people.where(contact_id: nil).where("COALESCE(tasks.sender_email, '') = ''") }
  def self.from_source(source)
    case source
    when "clients" then from_clients
    when "agents" then made_by_agents
    when "team" then from_team
    else all
    end
  end

  # Added by an agent (someone's AI, through a token), and which one: "Ted's agent".
  def made_by_agent? = User.agent_names.key?(created_by_id)
  def agent_name = User.agent_names[created_by_id]

  def request? = owner_id.nil? && status == "planned"

  def requester_name = contact&.name || sender_name.presence || sender_email

  # A notification about it: a request that came in.
  def notification_title = "#{requester_name || "Someone"} asked for something"
  def notification_excerpt = title


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

  # Put on another piece of work (filed from Intake), a section of the old one no longer applies.
  def drop_section_from_other_work
    self.scope_item = nil if scope_item && scope_item.work_id != work_id
  end

  def record_filing
    from, to = saved_change_to_work_id.map { Work.find_by(id: it)&.title }
    record_event!("task.filed", payload: { from: from, to: to }.compact)
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

    # Only a request from outside notifies anyone (Notifiable would for every task).
    def notify_recipients_later
      super if requested && Current.source != "import"
    end
end
