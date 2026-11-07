# Runwell for a client's own agent (MCP, Streamable HTTP, stateless): the portal's tools, run as
# the contact whose token it is, so it sees and does exactly what they can in the portal and
# nothing else of the business's. Bearer tokens only: a personal one from the portal's Connected apps,
# or OAuth, which signs the contact in by emailed link.
class Portal::McpController < Portal::BaseController
  agent_exempt :create, reason: "the client MCP endpoint itself"
  skip_forgery_protection

  INSTRUCTIONS = <<~TEXT
    You act for a client of a business (or of whoever runs this Runwell), through its portal: you see what they see there and can do what they can. Call `portal_me` first: who you act for and their company.

    `portal_works` lists what we run for them (work, named by ref like WO-12, or by title); `portal_work` shows one: its sections, the tasks shared with them, and documents. `portal_tasks` lists all shared tasks; `portal_requests` what they've asked for; `portal_send_request` asks for something new.

    Errors carry a stable `code` (usage, not_found, ambiguous, auth, refused, invalid, read_only, paused, rate_limited, failed) and a `hint`; branch on the code.
  TEXT

  def create
    catalogue = Agent::Catalogue.for_contact(current_contact, read_only: Current.access_token.read_only?)
    server = MCP::Server.new(name: "runwell-portal", title: "#{client.name} at #{Setting.current.brand_name}", version: "1.1.0",
      instructions: INSTRUCTIONS, tools: catalogue.map { mcp_tool(it) }, prompts: Agent::Prompts.client,
      resource_templates: Agent::Resources.templates(Agent::Resources::CLIENT),
      server_context: { token: bearer_token, base_url: request.base_url })
    server.resources_read_handler { |params| read_resource(catalogue, params[:uri].to_s) }
    result = server.handle_json(request.body.read)
    result ? render(json: result) : head(:accepted)
  end

  private
    # Bearer only, never the portal's cookie: that is what makes skipping CSRF safe here.
    def require_contact
      bearer_request? ? require_contact_token : request_portal_token
    end

    def read_resource(catalogue, uri)
      name, arguments = Agent::Resources.call_for(Agent::Resources::CLIENT, uri)
      tool = name && catalogue.find { it.name == name }
      raise MCP::Server::ResourceNotFoundError.new(uri) unless tool

      body = Agent::Dispatch.new(tool, arguments, token: bearer_token, base_url: request.base_url).call
      raise MCP::Server::ResourceNotFoundError.new(uri) if body["status"] == "error"

      [ { uri: uri, mimeType: "application/json", text: JSON.generate(body) } ]
    end

    def mcp_tool(tool)
      MCP::Tool.define(name: tool.name, title: tool.title, description: tool.full_description,
        input_schema: tool.input_schema, annotations: tool.annotations) do |server_context:, **arguments|
        body = Agent::Dispatch.new(tool, arguments, token: server_context[:token], base_url: server_context[:base_url]).call
        MCP::Tool::Response.new([ { type: "text", text: JSON.generate(body) } ], structured_content: body, error: body["status"] == "error")
      end
    end
end
