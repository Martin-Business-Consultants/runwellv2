# The plugins Runwell's authors publish (config/plugins.yml), offered in Settings > Plugins to
# install. Any other GitHub repository holding a Runwell plugin installs the same way.
module Runwell::PluginCatalog
  extend self

  # tables: prefixes of tables the plugin owns beyond its key's (a gem's own, like ruby_llm_).
  Entry = Data.define(:key, :repo, :name, :description, :tables)

  def entries = @entries ||= YAML.load_file(Rails.root.join("config/plugins.yml")).map { Entry.new(tables: [], **it.symbolize_keys) }
  def find(key) = entries.find { it.key == key.to_s }
  def keys = entries.map(&:key)
  def table_prefixes = entries.flat_map(&:tables)

  # Those not on this server yet.
  def available = entries.reject { InstalledPlugins.present.key?(it.key) }
end
