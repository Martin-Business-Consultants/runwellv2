# Whether a client's own agent may decide agreements for them (Portal::ApprovalsController),
# after showing the agreement and taking their typed name. On unless the owner turns it off.
class Settings::ClientAgentApprovalsController < Settings::BaseController
  agent_exempt :update, reason: "what clients' agents may do is the owner's call, made in the browser"

  def update
    Setting.current.update!(client_agent_approvals: params.dig(:setting, :client_agent_approvals) == "1")
    redirect_to settings_connected_apps_path, notice: Setting.current.client_agent_approvals? ? "Clients’ agents may decide agreements, with the client’s typed name." : "Clients decide agreements themselves; their agents can’t."
  end
end
