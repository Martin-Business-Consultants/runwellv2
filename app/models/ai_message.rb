# One message of an AiChat, kept by RubyLLM (acts_as_message): the person's (user), the AI's
# (assistant, with the tool calls it made), a tool's answer (tool) or the instructions (system).
# The panel shows people's and the AI's words, and what the AI looked at or proposed.
class AiMessage < ApplicationRecord
  acts_as_message chat: :ai_chat, touch_chat: true
  # Documents the person attached to a question (copies of the record's files), for the model to read.
  has_many_attached :attachments

  scope :shown, -> { where(role: %w[user assistant]) }
end
