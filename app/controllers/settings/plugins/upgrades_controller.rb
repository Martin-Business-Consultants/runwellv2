# A plugin's Update button: its repository's latest release, in place of the one installed.
# Plugins update only this way, never along with Runwell.
class Settings::Plugins::UpgradesController < Settings::BaseController
  agent_tool :update_plugin, on: :create, title: "Update an installed plugin to its newest release",
    description: "Only when list_plugins shows a newer release for it. Runwell restarts on the new release; if it won't load, the old one comes back.",
    confirm: "Runwell updates the plugin and restarts: it's unavailable for a few seconds."

  def create
    change = PluginChange.update!(params[:plugin_key], by: Current.user)
    redirect_to settings_plugins_path, notice: "#{change.summary}. Runwell restarts when it's done; this page shows how it went."
  rescue PluginChange::Refused, ActiveRecord::RecordInvalid => error
    redirect_to settings_plugins_path, alert: error.message
  end
end
