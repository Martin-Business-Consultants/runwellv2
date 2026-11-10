# Append-only. A correction is another event.
class Event < ApplicationRecord
  include TextFilterable

  # The audit log's filter: what happened, who did it (or the app they did it through) and its details.
  filters_text_on "events.kind", "events.actor", "events.subject_type", "events.payload", "users.name", joins: :actor_user
  belongs_to :subject, polymorphic: true
  belongs_to :actor_user, class_name: "User", optional: true
  # Deleting a record deletes its history; its webhook deliveries stay in the log, unlinked.
  has_many :webhook_deliveries, dependent: :nullify

  validates :kind, :source, :occurred_at, presence: true

  # Sign-ins, two-factor, roles and settings: the audit log's, not a record's history, so they're
  # kept out of `changes` (what agents catch up on).
  SECURITY_SUBJECTS = %w[User Setting].freeze

  scope :recent, -> { order(occurred_at: :desc) }
  # What agents did (User::Agent: someone's AI, through a token), everyone's or one person's.
  scope :by_agents, -> { where(actor_user_id: User.agents.select(:id)) }
  scope :by_agent_of, ->(person) { where(actor_user_id: person.agent&.id || 0) }

  # One area of the install's history, as the audit log and AI activity filter it.
  def self.in_area(area)
    case area
    when "security" then where(subject_type: SECURITY_SUBJECTS)
    when "works" then where("kind LIKE 'agreement.%' OR kind LIKE 'work.%' OR kind LIKE 'scope_item.%'")
    when "tasks" then where("kind LIKE 'task.%' OR kind LIKE 'commitment.%' OR kind LIKE 'note.%' OR kind LIKE 'document.%'")
    when "requests" then where("kind = 'task.requested' OR kind LIKE 'request.%' OR kind LIKE 'question.%'")
    when "clients" then where("kind LIKE 'client.%' OR kind LIKE 'contact.%'")
    else all
    end
  end

  before_update { raise ActiveRecord::ReadOnlyRecord, "events are append-only" }
  before_destroy { throw :abort unless destroyed_by_association }

  # Plugins hear of it from a job (EventPublishJob), so a slow subscriber never holds up the save.
  after_create_commit { EventPublishJob.perform_later(self) }

  def actor_name = actor_user&.display_name || actor || "system"

  # Where it came from, in words: "via Claude" for an agent acting for someone.
  def source_label = source == "agent" ? "via #{actor.presence || "an agent"}" : source
end
