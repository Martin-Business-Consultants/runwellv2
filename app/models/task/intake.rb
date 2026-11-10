# Intake (IntakesController): what came in and hasn't been decided. A task comes in (intake_at) when
# it's made without an owner or a piece of work: a client's request (the portal, an email, a call),
# a task an agent added, a task straight on a client. Not a repeat's next one, nor an import.
#
# It stays until a decision takes it out, each a verb that refuses a task that isn't waiting
# (Task::Refused): accept! (someone owns it: the one given, else whoever's on it, else whoever
# accepts; it may be filed on a piece of work later) and decline! (kept, marked done with the reason
# "Declined", so the client isn't emailed it's done and it doesn't repeat; their portal shows it as
# Declined). Assigning or filing it meanwhile doesn't: accepting is the decision. Marked done
# another way, it's no longer waiting either.
module Task::Intake
  extend ActiveSupport::Concern

  # Where it came from, as Intake filters it: a client (a contact, or an email's sender), an agent,
  # or someone on the team.
  SOURCES = %w[any clients agents team].freeze

  included do
    belongs_to :accepted_by, class_name: "User", optional: true
    belongs_to :declined_by, class_name: "User", optional: true

    scope :intake, -> { open.where.not(intake_at: nil).where(accepted_at: nil, declined_at: nil) }
    scope :from_clients, -> { where("tasks.contact_id IS NOT NULL OR COALESCE(tasks.sender_email, '') <> ''") }
    attr_accessor :skips_intake
    before_create :come_in, unless: -> { skips_intake || Current.source == "import" }

    scope :from_team, -> { made_by_people.where(contact_id: nil).where("COALESCE(tasks.sender_email, '') = ''") }
  end

  class_methods do
    def from_source(source)
      case source
      when "clients" then from_clients
      when "agents" then made_by_agents
      when "team" then from_team
      else all
      end
    end
  end

  def intake? = status != "done" && intake_at.present? && accepted_at.nil? && declined_at.nil?
  def acceptable? = intake?
  def declinable? = intake?
  def declined? = declined_at.present?

  # Someone owns it now: owner (a person), else whoever accepts it when nobody's on it.
  def accept!(by:, owner: nil)
    raise Task::Refused, "“#{title}” isn’t waiting in intake" unless acceptable?

    transaction do
      self.owner_id = (owner || by.person).id if owner || owner_id.nil?
      update!(accepted_at: Time.current, accepted_by: by)
      record_event!("task.accepted", payload: { owner: self.owner&.name })
    end
  end

  # Not wanted: kept for the record, out of every open list, and Declined in the client's portal
  # (nobody is emailed). note: why, kept as an internal note on it (the client never sees it).
  def decline!(by:, note: nil)
    raise Task::Refused, "“#{title}” isn’t waiting in intake" unless declinable?

    transaction do
      self.status_reason = "Declined"
      update!(status: "done", declined_at: Time.current, declined_by: by)
      notes.create!(body: "Declined: #{note.strip}", author: by, kind: "internal", source: Current.source || "app") if note.present?
      record_event!("task.declined", payload: { note: note.presence&.strip }.compact)
    end
  end

  private
    def come_in
      self.intake_at ||= Time.current if owner_id.nil? || work_id.nil?
    end
end
