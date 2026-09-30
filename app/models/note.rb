class Note < ApplicationRecord
  include Searchable, Mentions

  mentionable_fields :body

  KINDS = %w[call meeting email internal].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :author, class_name: "User", optional: true

  validates :body, :source, presence: true
  validates :kind, inclusion: { in: KINDS }

  before_validation { self.occurred_at ||= Time.current }

  scope :recent, -> { order(occurred_at: :desc) }

  # Its author (or the author's person, for a note an agent wrote), or anyone who may delete records.
  def deletable_by?(user)
    return false unless user

    author_id == user.id || (author&.agent_owner_id.present? && author.agent_owner_id == user.id) || user.can?(:delete_records)
  end

  def search_title = "#{kind.humanize} note"
  def search_content = body
  def search_client_id = subject.is_a?(Client) ? subject.id : subject.try(:client_id) || subject.try(:client)&.id
end
