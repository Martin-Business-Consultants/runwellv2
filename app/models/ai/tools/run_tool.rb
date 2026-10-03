# Runs a Runwell action found with find_tools, as the person. One that only reads runs at once.
# One that changes anything needs the person's approval first: RubyLLM pauses the chat on it,
# the Ask panel shows it to approve or decline (AiChat#decide!), and only then does it run, so the
# model can suggest but never act on its own.
class Ai::Tools::RunTool < Ai::Tool
  description "Run a Runwell action by name (from find_tools) with its arguments. Reading actions answer at once. Actions that change something wait for the person to approve them: propose one change per call, and say briefly what it does and why."
  parameters(
    type: "object",
    properties: {
      name: { type: "string", description: "The action's name, from find_tools" },
      arguments: { type: "object", description: "Its input, as its schema says", additionalProperties: true }
    },
    required: %w[name]
  )

  # Reads go ahead; anything else waits for the decision recorded on the tool call.
  requires_approval do |tool_call|
    action = Agent::Catalogue.find(tool_call.arguments.to_h.stringify_keys["name"])
    if action.nil? || action.read?
      true
    else
      { "approved" => true, "denied" => false }[RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: tool_call.id)&.approval]
    end
  end

  def self.tool_name = "run_tool"

  def execute(name:, arguments: {})
    tool = catalogue.find { it.name == name.to_s }
    return { error: "No action called #{name} for this person. Use find_tools." } unless tool

    arguments = arguments.to_h.stringify_keys.except("confirm", "idempotency_key")
    # Approved by the person, so an action that reaches a client is confirmed.
    arguments["confirm"] = true if tool.confirm && !tool.read?
    Ai.trim Ai.run_tool(user, tool, arguments)
  end
end
