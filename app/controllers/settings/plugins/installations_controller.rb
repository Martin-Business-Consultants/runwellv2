# Installs a plugin on this server from its GitHub repository's latest release: one Runwell
# publishes (by key) or any other (owner/name).
class Settings::Plugins::InstallationsController < Settings::BaseController
  agent_tool :install_plugin, on: :create, title: "Install a plugin from GitHub",
    description: "Downloads the latest release of a plugin's repository onto the server and restarts Runwell, which loads it and creates its tables. list_plugins names the ones Runwell publishes; any other repository installs by owner/name. It starts off: switch_plugin turns it on.",
    params: { repo: "string!" },
    confirm: "Runwell downloads the plugin and restarts: it's unavailable for a few seconds."

  def create
    repo = Runwell::PluginCatalog.find(params[:repo])&.repo || params[:repo]
    change = PluginChange.install!(repo, by: Current.user)
    redirect_to settings_plugins_path, notice: "#{change.summary}. Runwell restarts when it's done; then switch it on here."
  rescue PluginChange::Refused, ActiveRecord::RecordInvalid => error
    redirect_to settings_plugins_path, alert: error.message
  end
end
