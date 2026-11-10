# Intake (IntakesController): what came in and hasn't been dealt with. An open task is in it while
# nobody owns it, or, until someone accepts it, while it's on no piece of work: a client's request
# (the portal, an email, a call), a task an agent added, a task straight on a client.
#
# Two decisions take it out, each a verb that refuses a task that isn't waiting (Task::Refused):
# accept! (someone owns it: the one given, else whoever accepts; it may be filed on a piece of work
# later) and decline! (kept, marked done with the reason "Declined", so the client isn't emailed it's
# done and it doesn't repeat; their portal shows it as Declined). Filing it on a piece of work with
# someone on it takes it out too.
module Task::Intake
  extend ActiveSupport::Concern

  # Where it came from, as Intake filters it: a client (a contact, or an email's sender), an agent,
  # or someone on the team.
  SOURCES = %w[any clients agents team].freeze

  included do
    belongs_to :accepted_by, class_name: "User", optional: true
    belongs_to :declined_by, class_name: "User", optional: true

    scope :intake, -> { open.where("tasks.owner_id IS NULL OR (tasks.work_id IS NULL AND tasks.accepted_at IS NULL)") }
    scope :from_clients, -> { where("tasks.contact_id IS NOT NULL OR COALESCE(tasks.sender_email, '') <> ''") }
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

  def intake? = status != "done" && (owner_id.nil? || (work_id.nil? && accepted_at.nil?))
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
  # (nobody is emailed).
  def decline!(by:)
    raise Task::Refused, "“#{title}” isn’t waiting in intake" unless declinable?

    transaction do
      self.status_reason = "Declined"
      update!(status: "done", declined_at: Time.current, declined_by: by)
      record_event!("task.declined")
    end
  end
end
