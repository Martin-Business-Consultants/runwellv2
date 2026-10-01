# Every action says how an AI harness reaches it, so anything the UI can do an agent can too:
#
#   agent_tool :create_client, on: :create, title: "Add a client",
#     description: "…", params: { client: { name: "string!", status: Client::STATUSES } }
#   agent_exempt :preview, reason: "a live preview while typing; update_appearance saves"
#
# `new` and `edit` are exempt (form pages; their tools are create_* and update_*). An action
# with neither raises Undeclared in development and test, like a missing authorization rule,
# and `bin/rails agent:coverage` lists every action and its tool. Agent::Catalogue turns the
# declarations into MCP tools that run the real action (Agent::Tool).
module AgentTools
  extend ActiveSupport::Concern

  class Undeclared < StandardError; end

  AUTO_EXEMPT = { "new" => "a form page; use the create tool", "edit" => "a form page; use the update tool" }.freeze

  included do
    class_attribute :agent_declarations, instance_accessor: false, default: {}
    class_attribute :agent_public_actions, instance_accessor: false, default: []
    before_action :ensure_agent_declaration, if: -> { Rails.env.local? }
  end

  class_methods do
    # params: the request's params, as Rails sees them (nesting and all). A type is "string",
    # "text" (rich text: HTML or plain), "integer", "number", "boolean", "date", "file", an
    # array of allowed values, a nested hash, a list of one type ("integer[]"), or a list of
    # objects ([ { title: "string!" } ]); a trailing "!" makes it required. Path
    # parameters (id, ref, client_id…) come from the route; route: picks one by its path when
    # an action has several ("/engagements/:engagement_ref/commitments"). confirm: what reaches a client;
    # the tool then previews until called again with confirm: true.
    def agent_tool(name, on:, title:, description: nil, params: {}, confirm: nil, route: nil, follow: true, next_tools: [])
      self.agent_declarations = agent_declarations.merge(on.to_s => {
        name: name.to_s, title: title, description: description, params: params, confirm: confirm,
        route: route&.to_s, follow: follow, next_tools: next_tools.map(&:to_s)
      })
    end

    def agent_exempt(*actions, reason:)
      self.agent_declarations = agent_declarations.merge(actions.to_h { [ it.to_s, { exempt: reason } ] })
    end

    def agent_declaration_for(action)
      agent_declarations[action.to_s] ||
        (AUTO_EXEMPT[action.to_s] && { exempt: AUTO_EXEMPT[action.to_s] }) ||
        ((agent_public_actions == :all || agent_public_actions.include?(action.to_s)) && { exempt: "a public page, before signing in" })
    end
  end

  private
    def ensure_agent_declaration
      return if self.class.agent_declaration_for(action_name)

      raise Undeclared, "#{self.class.name}##{action_name} declares no agent tool: add agent_tool or agent_exempt"
    end
end
