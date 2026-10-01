require "json"

# The plugins installed on this server, loaded at boot (config/application.rb). They live in
# RUNWELL_DATA_DIR/plugins, one directory per plugin, so they outlast deploys and core updates:
# each is a Rails engine with a gemspec at its root, put there from Settings > Plugins
# (PluginChange). They aren't bundled, since Bundler freezes the Gemfile in production: a
# plugin's lib/ goes on the load path and its engine is required by name, so it may depend only
# on gems the core bundles. Its migrations run after the core's (lib/tasks/plugins.rake) and
# its tables stay out of the core's schema.rb. Not in Zeitwerk's lib/, so it loads once.
module InstalledPlugins
  extend self

  METADATA = ".runwell-plugin.json"

  def directory
    root = File.expand_path("..", __dir__)
    Pathname(File.expand_path(ENV.fetch("RUNWELL_DATA_DIR", "storage"), root)).join("plugins")
  end

  # Every plugin directory, by its gem name, which is also its key.
  def present
    return {} unless directory.directory?

    directory.children.sort.filter_map do |path|
      next unless path.directory? && !path.basename.to_s.start_with?(".")
      gemspec = path.glob("*.gemspec").first or next
      [ gemspec.basename(".gemspec").to_s, path ]
    end.to_h
  end

  def loaded = @loaded ||= {}
  def failed = @failed ||= {}
  # The release each was at when this process booted; the directory may since hold another.
  def versions = @versions ||= {}

  # Off in tests, which cover the core alone, and with RUNWELL_PLUGINS=off (to boot without a
  # plugin that keeps the app from starting).
  def load!
    return if ENV["RAILS_ENV"] == "test" || ENV["RUNWELL_PLUGINS"] == "off"

    present.each do |name, path|
      $LOAD_PATH.unshift path.join("lib").to_s
      require name
      loaded[name] = path
      versions[name] = metadata(name)["version"]
    rescue ScriptError, StandardError => error
      failed[name] = "#{error.class}: #{error.message}"
      warn "[plugins] #{name} didn't load: #{failed[name]}"
    end
  end

  # Where it came from and which release it is, written when it was installed.
  def metadata(name)
    path = (loaded[name] || present[name])&.join(METADATA)
    path&.exist? ? JSON.parse(path.read) : {}
  rescue JSON::ParserError
    {}
  end

  def migration_paths = loaded.values.map { it.join("db/migrate") }.select(&:directory?).map(&:to_s)
end
