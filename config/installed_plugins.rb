require "json"
require "fileutils"
require_relative "installed_plugin_gems"

# The plugins installed on this server, loaded at boot (config/application.rb). They live in
# RUNWELL_DATA_DIR/plugins, one directory per plugin, so they outlast deploys and core updates:
# each is a Rails engine with a gemspec at its root, put there from Settings > Plugins
# (PluginChange). They aren't bundled, since Bundler freezes the Gemfile in production: a
# plugin's lib/ goes on the load path and its engine is required by name, after the gems its
# gemspec depends on (InstalledPluginGems: the core's where it has them, else installed for it). Its migrations run after the core's (lib/tasks/plugins.rake) and
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

    InstalledPluginGems.core
    present.each do |name, path|
      InstalledPluginGems.activate!(name, path)
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

  # A plugin whose migration fails would stop the install starting (db:prepare runs before the
  # server, bin/docker-entrypoint). plugins:migrate sets it aside instead: the release that failed
  # goes to .<name>.failed with a note saying why, and the one it replaced comes back if it's
  # still beside it (.<name>.previous; its migrations already ran, and a plugin's migrations only
  # add before they remove, so the ones of the failed release that did run don't trouble it).
  # Without one the plugin is gone until it's installed again; its tables and data stay.
  # Settings > Plugins shows the note until the plugin is next installed or updated.
  SET_ASIDE_NOTE = ".runwell-set-aside.json"

  def set_aside!(name, error)
    path = directory.join(name)
    failed = directory.join(".#{name}.failed")
    previous = directory.join(".#{name}.previous")
    version = metadata(name)["version"]
    restored = previous.directory? ? JSON.parse(previous.join(METADATA).read)["version"] : nil rescue nil

    FileUtils.rm_rf failed
    File.rename path, failed
    File.rename previous, path if previous.directory?
    error = error.cause while error.cause # Rails wraps it: "An error has occurred, this and all later migrations canceled"
    note = { version: version, error: "#{error.class}: #{error.message}".truncate(2_000), restored: restored, at: Time.now.utc.iso8601 }
    failed.join(SET_ASIDE_NOTE).write(note.to_json)
    warn "[plugins] #{name} #{version} couldn't migrate and was set aside (#{note[:error].lines.first.strip}); " \
      "#{restored ? "#{restored} is back" : "Runwell starts without it"}"
    note
  end

  # Plugins set aside after a failed migration, by name: the release, why, and what came back.
  def set_aside
    return {} unless directory.directory?

    directory.glob(".*.failed/#{SET_ASIDE_NOTE}").sort.to_h do |note|
      [ note.dirname.basename.to_s.delete_prefix(".").delete_suffix(".failed"), JSON.parse(note.read) ]
    rescue JSON::ParserError
      [ note.dirname.basename.to_s.delete_prefix(".").delete_suffix(".failed"), {} ]
    end
  end

  def clear_set_aside(name) = FileUtils.rm_rf(directory.join(".#{name}.failed"))

  # Each loaded plugin's own JavaScript: app/javascript/<key>, by key. Only that folder, so a
  # plugin's modules are named for it ("my_day/…") and its Stimulus controllers too
  # ("my-day--copy-prompt"), and can't stand in for the core's (config/importmap_plugins.rb).
  def javascript_dirs
    loaded.filter_map { |name, path| [ name, path.join("app/javascript", name) ] if path.join("app/javascript", name).directory? }.to_h
  end
end
