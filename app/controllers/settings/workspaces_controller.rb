# Settings > Workspaces, for everyone: the other Runwell installs on your rail (WorkspaceLink).
# Adding one sends you there to confirm (Workspaces::LinksController), which links both ways;
# removing one unlinks both.
class Settings::WorkspacesController < ApplicationController
  allow_staff
  browser_only :index, :create, :destroy, reason: "linking workspaces exchanges keys between installs, which a person does in the browser"

  def index
    @links = Current.user.workspace_links.ordered.to_a
  end

  def create
    link, nonce = WorkspaceLink.start!(user: Current.user, url: params.expect(workspace: [ :url ])[:url], here: request.base_url)
    redirect_to "#{link.url}/workspace/link/new?#{{ from: request.base_url, nonce: nonce }.to_query}", allow_other_host: true
  rescue WorkspaceLink::Refused => error
    redirect_to settings_workspaces_path, alert: error.message
  end

  def destroy
    link = Current.user.workspace_links.find(params[:id])
    link.unlink!
    redirect_to settings_workspaces_path, notice: "#{link.label} is off your rail."
  end
end
