json.summary "Runwell #{Runwell::VERSION}: #{@plugins.count { Runwell::Plugins.enabled?(it.key) }} of #{@plugins.size} installed plugins on#{"; #{@change.summary.downcase}" if @change}"
json.runwell_version Runwell::VERSION
json.plugins @plugins do |plugin|
  json.key plugin.key
  json.extract! plugin, :name, :version, :description, :author, :requires, :homepage
  json.repo InstalledPlugins.metadata(plugin.key.to_s)["repo"]
  json.newer_release PluginRelease.newer(plugin.key)
  json.compatible plugin.compatible?
  json.enabled Runwell::Plugins.enabled?(plugin.key)
  json.adds Runwell::Plugins.additions(plugin.key)
end
json.failed_to_load InstalledPlugins.failed
json.available Runwell::PluginCatalog.available do |entry|
  json.extract! entry, :key, :repo, :name, :description
end
json.changes @changes do |change|
  json.extract! change, :id, :key, :repo, :action, :from_version, :to_version, :status, :message, :created_at, :finished_at
end
