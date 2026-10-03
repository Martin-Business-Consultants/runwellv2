# The Ask panel's conversation: index is the list of messages (reloaded by the panel while a
# reply is coming), create asks a question.
class Ai::MessagesController < ApplicationController
  allow_staff
  agent_exempt :index, :create, reason: "the in-app AI's own panel; agents use the tools directly over MCP"

  before_action :set_chat

  def index
  end

  def create
    attrs = params.expect(message: [ :content, document_ids: [] ])
    @chat.ask_soon!(attrs[:content], document_ids: attrs[:document_ids])
    redirect_to ai_chat_path(@chat)
  rescue Ai::Unavailable => error
    redirect_to ai_chat_path(@chat), alert: error.message
  end

  private
    def set_chat
      @chat = AiChat.asks.where(user: Current.user).find(params[:chat_id])
    end
end
