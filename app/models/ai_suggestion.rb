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
                   .with_schema(definition.schema.merge(name: kind))
                   .ask(definition.prompt_for(subject, user))
    parsed = response.content.is_a?(Hash) ? response.content : JSON.parse(response.content.to_s)
    update!(state: "ready", payload: parsed)
  rescue => error
    model = ai_chat&.model_id || Setting.current.ai_model_for(fast: definition.fast)
    update!(state: "failed", error: "#{Setting.current.ai_route_name(model)}: #{error.class.name.demodulize}: #{error.message}".truncate(300))
  end

  # The person uses it (with the items they ticked, for a list): applied with their permissions.
  def accept!(selection = [])
    message = definition.apply&.call(self, Array(selection).map(&:to_s), user) || "Noted."
    update!(state: "accepted")
    message
  end
  def dismiss! = update!(state: "dismissed")
end
