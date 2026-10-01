# One plugin installed, updated or removed from Settings > Plugins. Plugins live on the server,
# in RUNWELL_DATA_DIR/plugins (InstalledPlugins), each the latest release of a public GitHub
# repository. Installing or updating downloads that release, puts it in place and restarts the
# install, which loads it and runs its migrations on the way up; removing deletes its code and
# restarts, leaving its tables and data for a reinstall. A plugin updates only when someone
# presses its Update button. The change succeeds once the install boots with the plugin loaded at
# that release (or gone); an update that won't load puts the previous release back.
class PluginChange < ApplicationRecord
  class Refused < StandardError; end
  class Failed < StandardError; end

  ACTIONS = %w[install update remove].freeze
  STATUSES = %w[running succeeded failed].freeze
  TIMEOUT = 15.minutes
  REPO_FORMAT = %r{\A[\w.-]+/[\w.-]+\z}
  NAME_FORMAT = /\A[a-z][a-z0-9_]*\z/

  belongs_to :requested_by, class_name: "User", optional: true

  normalizes :repo, with: ->(value) { value.to_s.strip.sub(%r{\A(https?://)?github\.com/}, "").delete_suffix("/").delete_suffix(".git") }

  validates :action, inclusion: { in: ACTIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :repo, format: { with: REPO_FORMAT, message: "should be a GitHub repository, like owner/name" }

  scope :running, -> { where(status: "running") }
  scope :ordered, -> { order(created_at: :desc) }

  def self.current = running.ordered.first

  def self.install!(repo, by:) = start!(action: "install", repo: repo, by: by)

  def self.update!(key, by:)
    raise Refused, "#{key} is already at its newest release." unless PluginRelease.newer(key)
    start!(action: "update", key: key, repo: installed_repo(key), from_version: InstalledPlugins.versions[key.to_s], by: by)
  end

  def self.remove!(key, by:)
    start!(action: "remove", key: key, repo: installed_repo(key), from_version: InstalledPlugins.versions[key.to_s], by: by)
  end

  def self.start!(by:, **attributes)
    raise Refused, "#{current.summary} is under way; try once it's done." if current
    raise Refused, "Runwell is updating to #{Upgrade.current.to_version}; try once it's done." if Upgrade.current

    create!(requested_by: by, **attributes).tap { PluginChangeJob.perform_later(it) }
  end

  # Settles running changes once the install has restarted. Called on Settings > Plugins and nightly.
  def self.reconcile = running.find_each(&:reconcile!)

  # Plugins switched on whose code isn't here, put back as the install boots (PluginRestoreJob):
  # those that came with Runwell before plugins lived on the server. Each is tried once.
  def self.restore_missing
    keys = Setting.current.plugin_states.select { |_, on| on == true }.keys & Runwell::PluginCatalog.keys
    keys -= InstalledPlugins.present.keys + where(key: keys).pluck(:key)
    return if keys.empty? || current

    restored = keys.map { |key| create!(action: "install", key: key, repo: Runwell::PluginCatalog.find(key).repo).perform!(restart: false) }
    Runwell::Restart.later if restored.any?
  end

  def self.installed_repo(key)
    InstalledPlugins.metadata(key.to_s)["repo"] or raise Refused, "#{key} wasn't installed from Settings > Plugins, so it's updated and removed by hand."
  end

  # Run by PluginChangeJob. True once the change is in place and waits on the restart.
  def perform!(restart: true)
    action == "remove" ? take_out : put_in(latest_tag)
    Runwell::Restart.later if restart
    true
  rescue Failed, Release::Github::Error, SystemCallError, RuntimeError, JSON::ParserError => error
    fail! error.message
    false
  ensure
    FileUtils.rm_rf scratch if @scratch
  end

  def reconcile!
    if InstalledPlugins.failed[key] && action != "remove"
      roll_back
      fail! "#{key} #{to_version} didn't load (#{InstalledPlugins.failed[key]})#{"; #{from_version} is back" if action == "update"}."
    elsif done?
      update!(status: "succeeded", finished_at: Time.current)
    elsif created_at < TIMEOUT.ago
      fail! "No word after #{TIMEOUT.inspect}. The install's log says what happened."
    end
  end

  def fail!(message)
    update!(status: "failed", finished_at: Time.current, message: message)
  end

  def running? = status == "running"
  def succeeded? = status == "succeeded"
  def failed? = status == "failed"

  def summary
    name = key || repo
    case action
    when "install" then "Installing #{name}"
    when "update" then "Updating #{name} to #{to_version || "its newest release"}"
    else "Removing #{name}"
    end
  end

  private
    def github = Release::Github.new(repo: repo)
    def target = InstalledPlugins.directory.join(key)
    def previous = InstalledPlugins.directory.join(".#{key}.previous")
    def scratch = @scratch ||= InstalledPlugins.directory.join(".download-#{id}").tap { FileUtils.mkdir_p it }

    def done?
      if action == "remove"
        !InstalledPlugins.loaded.key?(key)
      else
        InstalledPlugins.loaded.key?(key) && InstalledPlugins.versions[key] == to_version
      end
    end

    def latest_tag
      github.get("releases/latest")["tag_name"].presence or raise Failed, "#{repo} has no release to install."
    end

    # Downloads the release, checks it's a plugin, and swaps it in. The one it replaces stays
    # beside it until the next change, to roll back to.
    def put_in(tag)
      update!(to_version: tag.delete_prefix("v"))
      archive = github.download("https://api.github.com/repos/#{repo}/tarball/#{tag}", scratch.join("plugin.tar.gz"))
      unpacked = scratch.join("plugin").tap { FileUtils.mkdir_p it }
      system("tar", "-xzf", archive.to_s, "-C", unpacked.to_s, "--strip-components=1", exception: true)

      gemspec = unpacked.glob("*.gemspec").first or raise Failed, "#{repo} #{tag} isn't a Runwell plugin: it has no gemspec at its root."
      name = gemspec.basename(".gemspec").to_s
      raise Failed, "#{repo} names its plugin #{name}, which isn't a plain lowercase name." unless name.match?(NAME_FORMAT)
      raise Failed, "#{repo} holds the #{name} plugin, not #{key}." if key && key != name
      raise Failed, "#{name} is already installed. Update or remove it instead." if action == "install" && InstalledPlugins.present.key?(name)

      update!(key: name)
      unpacked.join(InstalledPlugins::METADATA).write({ repo: repo, version: to_version, tag: tag, installed_at: Time.current.iso8601 }.to_json)
      FileUtils.rm_rf previous
      File.rename target, previous if target.exist?
      File.rename unpacked, target
    end

    def take_out
      raise Failed, "#{key} isn't installed." unless target.exist?

      FileUtils.rm_rf previous
      File.rename target, previous
      Setting.current.toggle_plugin!(key, enabled: false)
    end

    def roll_back
      return unless action == "update" && previous.exist?

      FileUtils.rm_rf target
      File.rename previous, target
      Runwell::Restart.later
    end
end
