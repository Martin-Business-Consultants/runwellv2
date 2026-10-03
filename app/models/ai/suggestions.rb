# The kinds of suggestion the in-app AI makes on records (AiSuggestion): each with the records it
# suits, a JSON schema for its answer, the prompt, and whether the fast model will do.
module Ai::Suggestions
  Definition = Struct.new(:kind, :label, :types, :fast, :schema, :prompt, keyword_init: true) do
    def prompt_for(subject) = prompt.call(subject)
  end

  DEFINITIONS = {}

  module_function

  def define(kind, **options) = DEFINITIONS[kind.to_s] = Definition.new(kind: kind.to_s, **options)
  def kinds = DEFINITIONS.keys
  def find(kind) = DEFINITIONS.fetch(kind.to_s)
end
