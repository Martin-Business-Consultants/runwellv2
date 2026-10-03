# The Ask panel (layouts/shared/ai_panel): the in-app AI's chat about the record on screen.
# show answers the panel for a chat; current finds the person's chat about a record (or starts
# one); create starts afresh. Chats are each person's own. Agents reach Runwell over MCP, so none
# of this is an agent tool.
class Ai::ChatsController < ApplicationController
  allow_staff
  agent_exempt :current, :show, :create, reason: "the in-app AI's own panel; agents use the tools directly over MCP"

  before_action :require_ai

  def current
    @chat = AiChat.for(Current.user, subject)
    render :show
  end

  def show
    @chat = AiChat.asks.where(user: Current.user).find(params[:id])
  end

  def create
    @chat = AiChat.start!(user: Current.user, subject: subject)
    redirect_to ai_chat_path(@chat)
  end

  private
    def subject
      return unless params[:record].present?

      type, id = params[:record].to_s.split(":", 2)
      return unless type.in?(AiChat::SUBJECT_TYPES)

      type == "Engagement" && !id.to_s.match?(/\A\d+\z/) ? Engagement.find_by(ref: id) : type.constantize.find_by(id: id)
    end

    def require_ai
      render "ai/chats/unavailable" unless Ai.ready?
    end
end
