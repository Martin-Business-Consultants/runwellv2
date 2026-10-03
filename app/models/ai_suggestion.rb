# Something the in-app AI suggested on a record, in a structured shape a person can use in one
# click: what a request should become, scope items for an agreement, work for a scope item,
# promises and tasks in a note, a summary. Made in a job (AiSuggestionJob) through its own AiChat,
# whose usage says what it cost; accepted or dismissed by the person, so Settings > AI can show
# which suggestions earn their keep.
class AiSuggestion < ApplicationRecord
  STATES = %w[working ready failed accepted dismissed].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true
  belongs_to :ai_chat, optional: true

  validates :kind, inclusion: { in: ->(_) { Ai::Suggestions.kinds } }
  validates :state, inclusion: { in: STATES }

  scope :latest_first, -> { order(created_at: :desc) }

  def self.latest(kind, subject, user) = where(kind: kind, subject: subject, user: user).latest_first.first

  def working? = state == "working" && created_at > 3.minutes.ago
  def ready? = state == "ready"
  def definition = Ai::Suggestions.find(kind)

  # Called by AiSuggestionJob: asks the fast or main model for this kind's structured answer.
  def generate!
    chat = AiChat.start!(user: user, subject: subject, purpose: "suggestion", fast: definition.fast)
    update!(ai_chat: chat)
    response = chat.with_instructions(Ai::Instructions.for(chat), persist: false)
                   .with_schema(definition.schema)
                   .ask(definition.prompt_for(subject))
    update!(state: "ready", payload: response.content.is_a?(Hash) ? response.content : JSON.parse(response.content.to_s))
  rescue => error
    update!(state: "failed", error: "#{error.class.name.demodulize}: #{error.message}".truncate(250))
  end

  def accept! = update!(state: "accepted")
  def dismiss! = update!(state: "dismissed")
end
