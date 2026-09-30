json.summary "Runwell #{Runwell::VERSION}: #{@plugins.count { Runwell::Plugins.enabled?(it.key) }} of #{@plugins.size} plugins on"
json.runwell_version Runwell::VERSION
json.plugins @plugins do |plugin|
  json.key plugin.key
  json.extract! plugin, :name, :version, :description, :author, :bundled, :requires, :homepage
  json.compatible plugin.compatible?
  json.enabled Runwell::Plugins.enabled?(plugin.key)
  json.adds Runwell::Plugins.additions(plugin.key)
end
