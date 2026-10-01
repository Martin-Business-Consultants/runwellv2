# Asks GitHub for each installed plugin's newest release now, rather than waiting for the night.
class Settings::Plugins::ChecksController < Settings::BaseController
  agent_tool :check_plugin_updates, on: :create, title: "Check every installed plugin for a newer release now"

  def create
    PluginRelease.check!
    newer = InstalledPlugins.present.keys.select { PluginRelease.newer(it) }

    if newer.any?
      redirect_to settings_plugins_path, notice: "Newer releases: #{newer.map { Runwell::Plugins.manifests[it.to_sym]&.name || it }.to_sentence}."
    else
      redirect_to settings_plugins_path, notice: "Every plugin is at its newest release."
    end
  end
end
