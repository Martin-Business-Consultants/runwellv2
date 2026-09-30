# Something only a person can answer. The main human inbox.
class Question < ApplicationRecord
  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  validates :text, :asked_by, :source, presence: true

  scope :unanswered, -> { where(answered_at: nil, dismissed_at: nil) }
  scope :ordered, -> { order(created_at: :asc) }

  def open? = answered_at.nil? && dismissed_at.nil?

  def answer!(answer)
    raise ArgumentError, "already closed" unless open?

    update!(answer: answer, answered_at: Time.current)
    subject.record_event!("question.answered", payload: { question: text, answer: answer }) if subject.respond_to?(:record_event!)
  end

  def dismiss!
    raise ArgumentError, "already closed" unless open?

    update!(dismissed_at: Time.current)
  end
end
