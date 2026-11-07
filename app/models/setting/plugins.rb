# Which plugins are switched on (Settings > Plugins). Every plugin starts off until the owner
# switches it on, like an installed but inactive WordPress plugin.
module Setting::Plugins
  def plugin_enabled?(key, default: false)
    plugin_states.fetch(key.to_s, default)
  end

  def toggle_plugin!(key, enabled:)
    update!(plugin_states: plugin_states.merge(key.to_s => enabled))
  end
end
