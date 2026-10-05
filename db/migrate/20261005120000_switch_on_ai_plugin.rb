# AI moved out of the core into the ai plugin (Runwell 2.18). An install that had it on keeps it:
# the plugin is switched on here, and the server installs it as it boots (PluginChange.restore_missing),
# whose own migrations copy the settings and the clients kept out of AI. The core's old columns stay
# until a later release.
class SwitchOnAiPlugin < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:settings, :ai_enabled)

    execute <<~SQL
      UPDATE settings SET plugin_states = json_set(COALESCE(plugin_states, '{}'), '$.ai', json('true')) WHERE ai_enabled = 1
    SQL
  end

  def down
  end
end
