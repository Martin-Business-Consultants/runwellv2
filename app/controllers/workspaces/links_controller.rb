# On B, the page another install (A) sends someone to after they added B to their rail: it says
# which install asks, and Link finishes both halves (WorkspaceLink.accept!, which calls A's
# handshake), then shows the rail with both.
class Workspaces::LinksController < ApplicationController
  allow_staff
  browser_only :new, :create, reason: "linking workspaces exchanges keys between installs, which a person does in the browser"

  def new
    @from = WorkspaceLink.origin(params[:from])
    @nonce = params[:nonce].to_s
  rescue WorkspaceLink::Refused => error
    redirect_to settings_workspaces_path, alert: error.message
  end

  def create
    link = WorkspaceLink.accept!(user: Current.user, from: params[:from], nonce: params[:nonce].to_s, here: request.base_url)
    redirect_to settings_workspaces_path, notice: "#{link.label} is on your rail, and this workspace is on its."
  rescue WorkspaceLink::Refused => error
    redirect_to settings_workspaces_path, alert: error.message
  end
end
