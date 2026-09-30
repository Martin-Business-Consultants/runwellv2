class Settings::PluginsController < Settings::BaseController
  agent_tool :list_plugins, on: :index, title: "List plugins"
  agent_tool :show_plugin, on: :show, title: "Show one plugin: what it does, whether it's on, and what it adds"
  agent_tool :switch_plugin, on: :update, title: "Switch a plugin on or off", params: { plugin: { enabled: "boolean!" } }

  def index
    @plugins = Runwell::Plugins.manifests.values
  end

  def show
    @plugin = find_manifest
  end

  def update
    manifest = find_manifest
    enabled = params.dig(:plugin, :enabled) == "1"
    Setting.current.toggle_plugin!(manifest.key, enabled: enabled)
    redirect_back fallback_location: settings_plugins_path, notice: "#{manifest.name} #{enabled ? "switched on" : "switched off"}."
  end

  private
    def find_manifest = Runwell::Plugins.manifests.fetch(params[:key].to_s.to_sym) { raise ActiveRecord::RecordNotFound }
end
