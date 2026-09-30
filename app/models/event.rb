# Append-only. A correction is another event.
class Event < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :actor_user, class_name: "User", optional: true

  validates :kind, :source, :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }

  before_update { raise ActiveRecord::ReadOnlyRecord, "events are append-only" }
  before_destroy { throw :abort unless destroyed_by_association }

  after_create_commit { ActiveSupport::Notifications.instrument("event.runwell", event: self) }

  def actor_name = actor_user&.display_name || actor || "system"

  # Where it came from, in words: "via Claude" for an agent acting for someone.
  def source_label = source == "agent" ? "via #{actor.presence || "an agent"}" : source
end
