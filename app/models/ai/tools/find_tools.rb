# The actions Runwell offers this person, found by what they do, with what each takes. The model
# finds one here, then runs it with run_tool.
class Ai::Tools::FindTools < Ai::Tool
  LIMIT = 8

  description "Find the Runwell actions for a job (\"create work\", \"resolve commitment\", \"briefing\", \"send agreement\"). Answers each action's name, what it does, whether it changes anything, and its input schema, to call with run_tool."
  parameter :query, description: "What you want to do, in a few words"

  def self.tool_name = "find_tools"

  def execute(query:)
    words = query.downcase.scan(/\w+/)
    ranked = catalogue.map { |tool| [ tool, score(tool, words) ] }.select { |_, s| s.positive? }.sort_by { -it.last }.first(LIMIT).map(&:first)
    return { found: [], hint: "Nothing matched; try other words, or search for records instead." } if ranked.empty?

    { found: ranked.map { |tool| { name: tool.name, does: tool.full_description.truncate(400), changes_something: !tool.read?, input: tool.input_schema.except(:type) } } }
  end

  private
    def score(tool, words)
      haystack = "#{tool.name.tr("_", " ")} #{tool.title} #{tool.description}".downcase
      words.sum { |word| (tool.name.include?(word) ? 3 : 0) + (haystack.include?(word) ? 1 : 0) }
    end
end
