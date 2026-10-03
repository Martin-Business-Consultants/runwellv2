# Settings > Plugins: the plugins installed on this server (RUNWELL_DATA_DIR/plugins), each
# switched on or off here, updated when someone presses its Update button, or removed; the ones
# Runwell publishes that aren't installed yet; and every install, update and removal with how
# it went (PluginChange).
class Settings::PluginsController < Settings::BaseController
  agent_tool :list_plugins, on: :index, title: "List plugins: installed (with any newer release), available to install, and recent changes"
  agent_tool :show_plugin, on: :show, title: "Show one plugin: what it does, whether it's on, and what it adds"
  agent_tool :switch_plugin, on: :update, title: "Switch a plugin on or off", params: { plugin: { enabled: "boolean!" } }
  agent_tool :remove_plugin, on: :destroy, title: "Remove an installed plugin",
    description: "Deletes the plugin's code from the server and restarts Runwell. Its tables and data stay, so installing it again brings them back.",
    confirm: "Runwell restarts without the plugin: it's unavailable for a few seconds."

  def index
    PluginChange.reconcile
    @plugins = Runwell::Plugins.manifests.values.sort_by(&:name)
    @change = PluginChange.current
    @changes = PluginChange.ordered.includes(:requested_by).limit(10)
  end

  def show
    @plugin = find_manifest
  end

  def update
    manifest = find_manifest
    enabled = params.dig(:plugin, :enabled) == "1"
    Setting.current.toggle_plugin!(manifest.key, enabled: enabled)
    Setting.current.record_event!("settings.plugin", payload: { plugin: manifest.key, on: enabled })
    redirect_back fallback_location: settings_plugins_path, notice: "#{manifest.name} #{enabled ? "switched on" : "switched off"}."
  end

  def destroy
    change = PluginChange.remove!(params[:key], by: Current.user)
    redirect_to settings_plugins_path, notice: "#{change.summary}. Runwell restarts when it's done; this page shows how it went."
  rescue PluginChange::Refused, ActiveRecord::RecordInvalid => error
    redirect_to settings_plugins_path, alert: error.message
  end

  private
    def find_manifest = Runwell::Plugins.manifests.fetch(params[:key].to_s.to_sym) { raise ActiveRecord::RecordNotFound }
end
