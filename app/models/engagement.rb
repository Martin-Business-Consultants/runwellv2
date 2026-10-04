# What we agreed with a client: scope, price, approval and every change since.
# The engagement is the container; each AgreementVersion is what the client saw.
class Engagement < ApplicationRecord
  include Eventful, Noted, Searchable, Mentions, Documentable
  include Refs, Agreement, CustomFields

  mentionable_fields :description, :estimate_notes

  LABELS = %w[project work_order service].freeze
  SHAPES = %w[fixed recurring].freeze

  belongs_to :client
  belongs_to :created_by, class_name: "User", optional: true
  has_many :agreement_versions, -> { order(:number) }, dependent: :destroy, inverse_of: :engagement
  has_many :todos, -> { order(:position) }, dependent: :destroy
  has_many :commitments, dependent: :destroy

  validates :title, presence: true
  validates :label, inclusion: { in: LABELS }
  validates :shape, inclusion: { in: SHAPES }

  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :ordered, -> { order(created_at: :desc) }

  # What a list shows, by derived state: "approved" (the default: underway, so agreed or
  # internal, and still open), "open" (every open one), "draft", "sent", "changes_requested",
  # "internal", "closed" or "all".
  FILTERS = %w[approved open draft sent changes_requested internal closed all].freeze

  # The derived state (Engagement#state), worked out by the database so a list can filter and count
  # by it without loading every engagement and its agreements: the same rules, in the same order.
  STATE_JOINS = <<~SQL.squish.freeze
    INNER JOIN clients state_clients ON state_clients.id = engagements.client_id
    LEFT JOIN agreement_versions latest_versions ON latest_versions.engagement_id = engagements.id
      AND latest_versions.number = (SELECT MAX(av.number) FROM agreement_versions av WHERE av.engagement_id = engagements.id)
    LEFT JOIN approvals latest_approvals ON latest_approvals.agreement_version_id = latest_versions.id
  SQL
  STATE_SQL = <<~SQL.squish.freeze
    CASE
      WHEN engagements.closed_at IS NOT NULL THEN 'closed'
      WHEN state_clients.internal THEN 'internal'
      WHEN latest_versions.id IS NULL OR latest_versions.sent_at IS NULL THEN 'draft'
      WHEN latest_approvals.id IS NULL AND latest_versions.superseded_by_id IS NULL THEN 'sent'
      WHEN latest_approvals.decision = 'changes_requested' THEN 'changes_requested'
      ELSE 'approved'
    END
  SQL

  def self.in_states(*states) = joins(STATE_JOINS).where(Arel.sql("(#{STATE_SQL}) IN (?)"), states.flatten)

  def self.filtered(state: "approved", label: "all", scope: all)
    state = FILTERS.include?(state) ? state : "approved"
    scope = scope.where(label: label) if LABELS.include?(label)
    scope = case state
    when "all" then scope
    when "closed" then scope.closed
    when "open" then scope.open
    when "approved" then scope.where(id: in_states("approved", "internal").select(:id))
    else scope.where(id: in_states(state).select(:id))
    end
    # Each row shows its state and agreed amount: versions and their decisions, for that page only.
    scope.ordered.includes(:client, agreement_versions: :approval)
  end

  # The filter's choices, each with how many it holds when `counts` (from filter_counts) is
  # given, so a draft is never lost behind the Approved default.
  def self.filter_options(counts = nil)
    options = [ [ "Active", "approved" ], [ "All open", "open" ], [ "Draft", "draft" ], [ "Sent", "sent" ],
      [ "Changes requested", "changes_requested" ], [ "Internal", "internal" ], [ "Closed", "closed" ], [ "All", "all" ] ]
    counts ? options.map { |text, value| [ "#{text} (#{counts.fetch(value, 0)})", value ] } : options
  end

  # How many engagements each filter choice would show, by derived state: one grouped query.
  def self.filter_counts(label: "all", scope: all)
    scope = scope.where(label: label) if LABELS.include?(label)
    tally = scope.joins(STATE_JOINS).group(Arel.sql(STATE_SQL)).count
    open = tally.except("closed").values.sum
    tally.merge("approved" => tally.fetch("approved", 0) + tally.fetch("internal", 0), "open" => open, "closed" => tally.fetch("closed", 0), "all" => open + tally.fetch("closed", 0))
  end

  # The list filter from params, reading the old status=open|closed too.
  def self.filter_from(params, key = :state)
    params[key].presence_in(FILTERS) || params[:status].presence_in(%w[open closed]) || "approved"
  end

  def closed? = closed_at.present?

  # Only a draft nobody was ever sent can be deleted; anything sent is history, so close it.
  def deletable? = agreement_versions.none?(&:sent?)
  def recurring? = shape == "recurring"

  # Gone for good: a closed engagement with its agreements (sent ones too), the client's decisions,
  # work, commitments, notes, documents and history. The one exception to "sent is forever", for an
  # owner (erase_engagements) who types the ref to mean it; the client keeps one event saying so.
  def erase!(actor: Current.user, source: Current.source || "app")
    raise ArgumentError, "close it first" unless closed?

    summary = { ref: ref, title: title, versions: agreement_versions.count(&:sent?), todos: todos.count }
    transaction do
      Current.set(erasing: true) { destroy! }
      client.record_event!("engagement.erased", actor: actor, source: source, payload: summary)
    end
  end

  # How it ended: completed (delivered) or cancelled (stopped before then). Either way it's closed.
  CLOSE_OUTCOMES = %w[completed cancelled].freeze

  def close!(reason: nil, outcome: "completed", actor: Current.user, source: Current.source || "app")
    outcome = outcome.presence_in(CLOSE_OUTCOMES) || "completed"
    transaction do
      update!(closed_at: Time.current, close_reason: reason, close_outcome: outcome)
      record_event!("engagement.closed", actor: actor, source: source, payload: { outcome: outcome, reason: reason })
    end
  end

  # Closed by mistake, or work starting again: open as it was, its history keeping both.
  def reopen!(actor: Current.user, source: Current.source || "app")
    transaction do
      update!(closed_at: nil, close_reason: nil, close_outcome: nil)
      record_event!("engagement.reopened", actor: actor, source: source)
    end
  end

  # The state in words: "Completed" or "Cancelled" once closed, else the state itself.
  def state_label
    return (close_outcome.presence || "closed").humanize if closed?

    state.humanize
  end

  def label_name = Setting.current.label_name(label)

  # Every file the client may see for this engagement: its own, its scope items', its
  # work's, and the client's.
  def client_documents
    Document.client_visible.where(documentable: self)
      .or(Document.client_visible.where(documentable_type: "ScopeItem", documentable_id: agreement_versions.select(:id).then { ScopeItem.where(agreement_version_id: it).select(:id) }))
      .or(Document.client_visible.where(documentable_type: "Todo", documentable_id: todos.client_visible.select(:id)))
      .or(Document.client_visible.where(documentable: client))
      .recent.includes(file_attachment: :blob)
  end

  def to_param = ref

  def search_title = "#{ref} #{title}"
  def search_content = description

  ActiveSupport.run_load_hooks(:runwell_engagement, self)
end
