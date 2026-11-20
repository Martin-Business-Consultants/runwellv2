# Requests by email moved out of the core into the inbound plugin (Runwell 7.0). An install that
# received mail keeps receiving it: the plugin is switched on here, and the server installs it as it
# boots (PluginChange.restore_missing), whose own migration copies the requests address, the
# service and its password. The core's columns stay, unread, until a later release.
class SwitchOnInboundPlugin < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:settings, :requests_email)

    execute <<~SQL
      UPDATE settings SET plugin_states = json_set(COALESCE(plugin_states, '{}'), '$.inbound', json('true'))
      WHERE requests_email IS NOT NULL OR inbound_ingress IS NOT NULL
    SQL
  end

  def down
  end
end
