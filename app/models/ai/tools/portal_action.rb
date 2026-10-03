# The portal assistant's one tool: the client portal's own actions, as the signed-in contact, so
# it sees exactly what their portal shows. Reading runs at once; sending a request waits for the
# contact to approve it. Deciding on an agreement is never offered: a person does that themselves.
class Ai::Tools::PortalAction < Ai::Tool
  ALLOWED = %w[portal_me portal_engagements portal_engagement portal_work portal_requests portal_send_request].freeze

  description "Use the client portal: #{ALLOWED.join(", ")}. portal_engagement takes { ref }. portal_send_request takes { request: { subject, body } } and waits for the client to approve it."
  parameters(
    type: "object",
    properties: {
      name: { type: "string", enum: ALLOWED },
      arguments: { type: "object", additionalProperties: true }
    },
    required: %w[name]
  )

  requires_approval do |tool_call|
    action = Agent::Catalogue.find(tool_call.arguments.to_h.stringify_keys["name"])
    if action.nil? || action.read?
      true
    else
      { "approved" => true, "denied" => false }[RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: tool_call.id)&.approval]
    end
  end

  def self.tool_name = "portal_action"

  def execute(name:, arguments: {})
    return { error: "Not available here." } unless name.to_s.in?(ALLOWED)

    tool = Agent::Catalogue.for_contact(@chat.contact).find { it.name == name.to_s }
    return { error: "Not available here." } unless tool

    arguments = arguments.to_h.stringify_keys.except("confirm", "idempotency_key")
    arguments["confirm"] = true if tool.confirm && !tool.read? # the contact just approved it
    Ai.trim Ai.run_portal_tool(@chat.contact, tool, arguments)
  end
end
