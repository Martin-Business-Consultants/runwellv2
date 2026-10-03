# A tool the in-app AI may call, bound to one chat (and so one person, and the record the chat is
# about). RubyLLM sends its name, description and parameters to the model, runs #execute with what
# the model chose, and keeps the call and its answer on the chat (ruby_llm_tool_calls).
class Ai::Tool < RubyLLM::Tool
  def initialize(chat)
    @chat = chat
    super()
  end

  private
    def user = @chat.user
    def catalogue = Agent::Catalogue.for(user)
end
