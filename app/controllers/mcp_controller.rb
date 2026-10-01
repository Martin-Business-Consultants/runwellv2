# Runwell over the Model Context Protocol (Streamable HTTP, stateless): one tool per declared
# controller action (AgentTools), offered by role and by which plugins are on, each run as the
# real request with the caller's token (Agent::Dispatch). Clients sign in with a bearer token:
# a personal one from Settings > Connected apps, or OAuth for connectors.
class McpController < ApplicationController
  allow_staff
  agent_exempt :create, reason: "the MCP endpoint itself"
  skip_forgery_protection

  INSTRUCTIONS = <<~TEXT
    Runwell is an agency's project management: who we work for (clients, and contacts who can approve), what we agreed (engagements holding agreement versions: drafts until sent, frozen once sent), what is happening (work/todos, commitments with dates, notes, documents), what came in (requests to triage), and what needs a person now (the briefing).

    Start with `briefing`. Use `search` to find anything, and `me` for who you are, your role, the team's ids, and why a tool might be missing. Engagements are named by ref (WO-12, P-3, S-4). Tools that take a `record` want "Type:id", like "Client:12", as every result's `record` field shows. Rich text fields take HTML or plain text; write a person's name after @ to mention them.

    Anything that reaches a client (sending an agreement, emailing a link, portal visibility) answers first with a preview (status needs_confirmation). Tell the person what will happen and call again with confirm: true only after they agree. You act as the person's agent, with exactly their role: what you do is recorded as "<Person>'s agent via <this app>". Each result has a `url` so the person can open it.

    An error carries a stable `code` (usage, not_found, auth, forbidden, refused, invalid, read_only, failed) and a `hint` saying what to do; branch on the code, not the wording. A success may carry `next`: suggested follow-up commands with what's known filled in.
  TEXT

  def create
    tools = Agent::Catalogue.for(current_user, read_only: Current.access_token&.read_only?).map { mcp_tool(it) }
    server = MCP::Server.new(name: "runwell", title: "Runwell", version: "1.0.0", instructions: instructions, tools: tools,
      server_context: { token: request.authorization.to_s.delete_prefix("Bearer ").strip, base_url: request.base_url })
    result = server.handle_json(request.body.read)
    result ? render(json: result) : head(:accepted)
  end

  private
    # The core's, then each switched-on plugin's workflows.
    def instructions
      workflows = Runwell::Plugins.enabled_agent_workflows.values.map { |title, text| "## #{title}\n\n#{text.strip}" }
      ([ INSTRUCTIONS.strip ] + workflows).join("\n\n")
    end

    # Bearer tokens only, never a browser's session cookie: that is what makes skipping CSRF
    # protection here safe. Without a token, 401 with where to sign in.
    def require_authentication
      authenticate_by_token || request_token_authentication
    end

    def mcp_tool(tool)
      MCP::Tool.define(name: tool.name, title: tool.title, description: tool.full_description,
        input_schema: tool.input_schema, annotations: tool.annotations) do |server_context:, **arguments|
        body = Agent::Dispatch.new(tool, arguments, token: server_context[:token], base_url: server_context[:base_url]).call
        MCP::Tool::Response.new([ { type: "text", text: JSON.generate(body) } ], structured_content: body, error: body["status"] == "error")
      end
    end
end
