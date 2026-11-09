# Something we run for a client: a project, a work order or a service. It holds its sections
# (ScopeItem) and its work, and is active until closed.
class Work < ApplicationRecord
  include Eventful, Noted, Searchable, Mentions, Documentable
  include Refs, CustomFields
  include LiveRefreshes, RecordsCreation

  mentionable_fields :description

  LABELS = %w[project work_order service].freeze
  SHAPES = %w[fixed recurring].freeze

  belongs_to :client
  belongs_to :created_by, class_name: "User", optional: true
  has_many :scope_items, -> { order(:position) }, dependent: :destroy, inverse_of: :work
  has_many :tasks, -> { order(:position) }, dependent: :destroy

  validates :title, presence: true
  validates :label, inclusion: { in: LABELS }
  validates :shape, inclusion: { in: SHAPES }

  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :ordered, -> { order(created_at: :desc) }

  # What a list shows: "open" (the default), "internal" (open, on the business itself), "closed"
  # or "all".
  FILTERS = %w[open internal closed all].freeze

  def self.filtered(state: "open", label: "all", scope: all)
    state = FILTERS.include?(state) ? state : "open"
    scope = scope.where(label: label) if LABELS.include?(label)
    scope = case state
    when "all" then scope
    when "closed" then scope.closed
    when "internal" then scope.open.where(client: Client.where(internal: true))
    else scope.open
    end
    scope.ordered.includes(:client).select("works.*", "EXISTS (SELECT 1 FROM tasks WHERE tasks.work_id = works.id) AS has_tasks")
  end

  # The filter's choices, each with how many it holds when `counts` (from filter_counts) is given.
  def self.filter_options(counts = nil)
    options = [ [ "Open", "open" ], [ "Internal", "internal" ], [ "Closed", "closed" ], [ "All", "all" ] ]
    counts ? options.map { |text, value| [ "#{text} (#{counts.fetch(value, 0)})", value ] } : options
  end

  # How many pieces of work each filter choice would show: one grouped query.
  def self.filter_counts(label: "all", scope: all)
    scope = scope.where(label: label) if LABELS.include?(label)
    tally = scope.joins(:client).group(Arel.sql("works.closed_at IS NULL"), "clients.internal").count
    open = tally.select { |(open, _), _| open == 1 || open == true }.values.sum
    internal = tally.select { |(open, internal), _| (open == 1 || open == true) && (internal == 1 || internal == true) }.values.sum
    closed = tally.values.sum - open
    { "open" => open, "internal" => internal, "closed" => closed, "all" => open + closed }
  end

  # The list filter from params. Links from before 3.0 named derived states (approved, draft,
  # sent…): every one of those was open.
  def self.filter_from(params, key = :state)
    value = params[key].presence || params[:status].presence
    value.presence_in(FILTERS) || "open"
  end

  def state = closed? ? "closed" : "active"
  def active? = !closed?
  def internal? = client&.internal? || false

  def closed? = closed_at.present?

  # Deleted only while nothing hangs on it; once work is under way, close it (or erase it).
  def deletable? = has_attribute?(:has_tasks) ? !has_tasks : tasks.none?
  def recurring? = shape == "recurring"

  # Gone for good: a closed work with its sections, tasks, notes, documents and history, for
  # an owner (erase_works) who types the ref to mean it; the client keeps one event saying so.
  def erase!(actor: Current.user, source: Current.source || "app")
    raise ArgumentError, "close it first" unless closed?

    summary = { ref: ref, title: title, tasks: tasks.count }
    transaction do
      Current.set(erasing: true) { destroy! }
      client.record_event!("work.erased", actor: actor, source: source, payload: summary)
    end
  end

  # How it ended: completed (delivered) or cancelled (stopped before then). Either way it's closed.
  CLOSE_OUTCOMES = %w[completed cancelled].freeze

  # A move its state doesn't allow (closing what's closed, reopening what's open), refused by the
  # verb itself; the page, the bulk bar and the tools ask closable? / reopenable? first, to say why.
  class Refused < StandardError; end

  # Its moves: active closes (completed or cancelled), closed reopens. To change how it ended,
  # reopen it and close it again, so its history tells both.
  def closable? = active?
  def reopenable? = closed?

  def close!(reason: nil, outcome: "completed", actor: Current.user, source: Current.source || "app")
    raise Refused, "#{title} is already #{state_label.downcase}." unless closable?

    outcome = outcome.presence_in(CLOSE_OUTCOMES) || "completed"
    transaction do
      update!(closed_at: Time.current, close_reason: reason, close_outcome: outcome)
      record_event!("work.closed", actor: actor, source: source, payload: { outcome: outcome, reason: reason })
    end
  end

  # Closed by mistake, or work starting again: open as it was, its history keeping both.
  def reopen!(actor: Current.user, source: Current.source || "app")
    raise Refused, "#{title} is open." unless reopenable?

    transaction do
      update!(closed_at: nil, close_reason: nil, close_outcome: nil)
      record_event!("work.reopened", actor: actor, source: source)
    end
  end

  # How its tasks stand: [done, open].
  def task_progress = tasks.partition { it.status == "done" }.map(&:size)

  # The state in words: "Completed" or "Cancelled" once closed, else the state itself.
  def state_label
    return (close_outcome.presence || "closed").humanize if closed?

    "Active"
  end

  def label_name = Setting.current.label_name(label)

  # Every file the client may see for this work: its own, its sections', its work's, and
  # the client's.
  def client_documents
    Document.client_visible.where(documentable: self)
      .or(Document.client_visible.where(documentable_type: "ScopeItem", documentable_id: scope_items.select(:id)))
      .or(Document.client_visible.where(documentable_type: "Task", documentable_id: tasks.client_visible.select(:id)))
      .or(Document.client_visible.where(documentable: client))
      .recent.includes(file_attachment: :blob)
  end

  def to_param = ref

  def search_title = title
  def search_content = [ ref, description ].compact_blank.join(" ")

  ActiveSupport.run_load_hooks(:runwell_work, self)

  private
    def live_streams = [ self, :works, client ]
end
