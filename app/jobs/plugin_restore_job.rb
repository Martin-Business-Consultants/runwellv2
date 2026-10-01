# Run once as the install boots: puts back plugins that are switched on but whose code isn't on
# the server, like those that came with Runwell before plugins lived in RUNWELL_DATA_DIR/plugins.
class PluginRestoreJob < ApplicationJob
  def perform
    PluginChange.restore_missing
  end
end
