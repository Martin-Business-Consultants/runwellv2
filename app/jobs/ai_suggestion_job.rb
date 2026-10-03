# Makes an AiSuggestion (AiSuggestion#generate!), away from the request.
class AiSuggestionJob < ApplicationJob
  def perform(suggestion)
    suggestion.generate!
  end
end
