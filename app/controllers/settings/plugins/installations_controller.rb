# Installs a plugin on this server from its GitHub repository's latest release, named owner/repo:
# the only way a plugin arrives (an install starts with none, and Runwell offers no catalog).
class Settings::Plugins::InstallationsController < Settings::BaseController
  agent_tool :install_plugin, on: :create, title: "Install a plugin from GitHub",
    description: "Downloads the latest release of a plugin's repository onto the server and restarts Runwell, which loads it and creates its tables. Name the repository as owner/repo (github.com/owner/repo works too). It starts off: switch_plugin turns it on.",
    params: { repo: "string!" },
    confirm: "Runwell downloads the plugin and restarts: it's unavailable for a few seconds."

  def create
    repo = params[:repo].to_s.strip.delete_prefix("https://").delete_prefix("github.com/").delete_suffix(".git").delete_suffix("/")
    raise PluginChange::Refused, "Give the plugin's GitHub repository as owner/repo." unless repo.match?(%r{\A[\w.-]+/[\w.-]+\z})
    change = PluginChange.install!(repo, by: Current.user)
    redirect_to settings_plugins_path, notice: "#{change.summary}. Runwell restarts when it's done; then switch it on here."
  rescue PluginChange::Refused, ActiveRecord::RecordInvalid => error
    redirect_to settings_plugins_path, alert: error.message
  end
end
