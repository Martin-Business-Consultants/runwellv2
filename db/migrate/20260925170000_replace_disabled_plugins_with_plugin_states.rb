class ReplaceDisabledPluginsWithPluginStates < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :plugin_states, :json, null: false, default: {}
    remove_column :settings, :disabled_plugins, :json, null: false, default: []
  end
end
