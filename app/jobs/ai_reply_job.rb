# Writes the in-app AI's reply (AiChat#reply!), away from the request.
class AiReplyJob < ApplicationJob
  def perform(chat)
    chat.reply!
  end
end
