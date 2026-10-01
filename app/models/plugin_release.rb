# The newest release of each installed plugin, from its repository on GitHub, for its Update
# button in Settings > Plugins. Checked nightly (ReleaseCheckJob) and by Check for updates, and
# kept on the settings row so a page never waits on GitHub. A plugin updates only when someone
# presses its button.
class PluginRelease
  def self.check!
    releases = InstalledPlugins.present.keys.to_h do |name|
      repo = InstalledPlugins.metadata(name)["repo"]
      data = Release::Github.new(repo: repo).get("releases/latest") if repo
      [ name, data && { "version" => data["tag_name"].to_s.delete_prefix("v"), "url" => data["html_url"], "notes" => data["body"] } ]
    rescue Release::Github::Error => error
      Rails.logger.warn "[plugins] #{name}: #{error.message}"
      [ name, Setting.current.plugin_releases[name] ]
    end
    Setting.current.update!(plugin_releases: releases.compact)
  end

  def self.for(name) = Setting.current.plugin_releases[name.to_s]

  # A newer release than the one running, or nil.
  def self.newer(name)
    latest = self.for(name)&.dig("version")
    running = InstalledPlugins.versions[name.to_s]
    latest if Gem::Version.correct?(latest) && Gem::Version.correct?(running) && Gem::Version.new(latest) > Gem::Version.new(running)
  end
end
