json.summary "#{@plugin.name} #{@plugin.version}: #{Runwell::Plugins.enabled?(@plugin.key) ? "on" : "off"}"
json.key @plugin.key
json.extract! @plugin, :name, :version, :description, :author, :requires, :homepage
json.repo InstalledPlugins.metadata(@plugin.key.to_s)["repo"]
json.newer_release PluginRelease.newer(@plugin.key)
json.compatible @plugin.compatible?
json.enabled Runwell::Plugins.enabled?(@plugin.key)
json.adds Runwell::Plugins.additions(@plugin.key)
json.has_settings Runwell::Plugins.settings_pages.key?(@plugin.key)
