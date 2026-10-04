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

  class ConversionRefused < StandardError; end

  # What a piece of work keeps that converting moves (notes and documents, to its engagement) or
  # lets go with it (its own history, mentions and custom field values). Anything else on it came
  # from a plugin (logged time, a linked repository, a QA gate) and stops a conversion.
  CONVERTIBLE_ASSOCIATIONS = %i[custom_values documents mentions mentionees notes events].freeze

  # The board's columns, in Fizzy's anatomy: the planned stream, the doing columns, done.
  BOARD_COLUMNS = %w[in_progress in_review blocked].freeze

  # Work that was really a promise ("Send the invoice by Friday"): becomes a commitment on the
  # engagement's client, ours (its owner's, else the actor's) or the client's, due when it was due
  # (or the date given, else in a week). Its notes and documents move to the engagement, the
  # engagement's history records the change, and the work goes. Refused while a plugin keeps
  # something on it, or once it's done.
  def convert_to_commitment!(owner_kind: "us", due_on: nil, actor: Current.user)
    raise ConversionRefused, "It’s done; a commitment is for what’s still to come." if status == "done"
    if (kept = conversion_blockers).any?
      raise ConversionRefused, "It has #{kept.to_sentence} on it, which a commitment can’t keep. Leave it as #{Setting.current.term(:work).downcase}."
    end

    transaction do
      commitment = engagement.client.commitments.create!(
        engagement: engagement, description: title, owner_kind: owner_kind.presence_in(Commitment::OWNER_KINDS) || "us",
        user: (owner_kind == "client" ? nil : owner || actor&.person), due_on: due_on.presence || self.due_on || 1.week.from_now.to_date,
        source: "work")
      commitment.record_event!("commitment.added", actor: actor, payload: { from_work: id })
      notes.update_all(subject_type: "Engagement", subject_id: engagement_id)
      documents.update_all(documentable_type: "Engagement", documentable_id: engagement_id)
      engagement.record_event!("todo.converted", actor: actor, payload: { title: title, commitment: commitment.id })
      destroy!
      commitment
    end
  end

  def conversion_blockers
    self.class.reflect_on_all_associations(:has_many).reject { it.name.in?(CONVERTIBLE_ASSOCIATIONS) }
      .select { public_send(it.name).exists? }.map { it.name.to_s.humanize.downcase }
  end

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
