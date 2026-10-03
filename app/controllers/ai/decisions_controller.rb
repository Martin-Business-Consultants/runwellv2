# Approving or declining a change the in-app AI proposed (AiChat#decide!). Approving runs it as
# the person; either way the AI carries on.
class Ai::DecisionsController < ApplicationController
  allow_staff
  agent_exempt :create, reason: "a person deciding on what the in-app AI proposed"

  def create
    chat = AiChat.asks.where(user: Current.user).find(params[:chat_id])
    chat.decide!(params[:tool_call_id], approve: params[:decision] == "approve")
    redirect_to ai_chat_path(chat)
  end
end
