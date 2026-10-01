# Updates a Docker install in place, the way WordPress updates itself: downloads the release's
# bundle (the app as its image holds it, gems and compiled assets included, built for each
# architecture by .github/workflows/release.yml) into releases/ in the data directory, checks it,
# points releases/current at it and restarts the container. On boot bin/docker-entrypoint runs
# whichever is newer, the image or releases/current, then backs up and migrates as always.
# Deploying a newer image takes over again.
#
# A release that needs another Ruby or other system packages (RUNWELL_BASE in the Dockerfile)
# can't come this way, nor can an install with plugins of its own in plugins/: those redeploy.
require "digest"

class Upgrade::InPlace
  class Failed < StandardError; end

  # The release running and the one before it, to go back to by hand.
  KEEP = 2

  def self.available? = ENV["RUNWELL_RUNTIME"] == "docker"
  def self.releases = Runwell.data_dir.join("releases")
  def self.arch = RbConfig::CONFIG["host_cpu"].in?(%w[aarch64 arm64]) ? "arm64" : "amd64"

  def initialize(upgrade)
    @upgrade = upgrade
  end

  def start = UpgradeJob.perform_later(@upgrade)

  # Run by UpgradeJob. A job that runs again after the restart finds the new version running.
  def install
    return @upgrade.reconcile! if Gem::Version.new(Runwell::VERSION) >= Gem::Version.new(@upgrade.to_version)

    refuse_own_plugins
    refuse_incompatible fetch_manifest
    unpack download
    switch
    prune
    restart
  rescue Failed, Release::Github::Error, SystemCallError, RuntimeError, JSON::ParserError => error
    @upgrade.fail! error.message
  ensure
    FileUtils.rm_rf @scratch if @scratch
  end

  # The job reports its own failure; a restart that never comes back is the timeout's.
  def check
  end

  def where_to_look = "The container's log (kamal app logs) says what happened."

  private
    def tag = @upgrade.tag
    def directory = self.class.releases.join(tag)
    def assets = @assets ||= github.get("releases/tags/#{tag}")["assets"].to_h { [ it["name"], it["browser_download_url"] ] }
    def github = Release::Github.new

    def asset_url(name)
      assets[name] or raise Failed, "#{tag} has no #{name} yet. GitHub builds it in the minutes after a release; try again shortly."
    end

    def refuse_own_plugins
      return if Dir[Rails.root.join("plugins/*/*.gemspec")].none?

      raise Failed, "This install has plugins of its own in plugins/, which a release doesn't carry. Redeploy the image to update it."
    end

    def fetch_manifest
      JSON.parse(download_to("runwell-#{tag}.json", scratch.join("manifest.json")).read)
    end

    def refuse_incompatible(manifest)
      if manifest["ruby"] != RUBY_VERSION || manifest["base"].to_s != ENV["RUNWELL_BASE"].to_s
        raise Failed, "#{tag} needs a new image (Ruby #{manifest["ruby"]}, base #{manifest["base"]}; this one has Ruby #{RUBY_VERSION}, base #{ENV["RUNWELL_BASE"]}). Redeploy to update."
      end
    end

    def download
      name = "runwell-#{tag}-linux-#{self.class.arch}.tar.gz"
      archive = download_to(name, scratch.join(name))
      expected = download_to("#{name}.sha256", scratch.join("#{name}.sha256")).read.split.first

      raise Failed, "#{name} didn't match its checksum. Nothing was changed." unless Digest::SHA256.file(archive).hexdigest == expected
      archive
    end

    def download_to(name, path) = Pathname(github.download(asset_url(name), path))

    def unpack(archive)
      partial = self.class.releases.join(".#{tag}.partial")
      FileUtils.rm_rf partial
      FileUtils.mkdir_p partial
      system("tar", "-xzf", archive.to_s, "-C", partial.to_s, exception: true)

      raise Failed, "The #{tag} bundle holds #{partial.join("VERSION").read.strip}, not #{@upgrade.to_version}." unless partial.join("VERSION").read.strip == @upgrade.to_version

      FileUtils.rm_rf directory
      File.rename partial, directory
    end

    # Atomic: a new link beside the old, renamed over it.
    def switch
      link = self.class.releases.join("current")
      fresh = self.class.releases.join(".current")
      FileUtils.rm_f fresh
      File.symlink tag, fresh
      File.rename fresh, link
    end

    def prune
      kept = self.class.releases.glob("v*").select(&:directory?).sort_by { Gem::Version.new(it.basename.to_s.delete_prefix("v")) }.last(KEEP)
      (self.class.releases.glob("v*").select(&:directory?) - kept - [ Rails.root ]).each { FileUtils.rm_rf it }
    end

    # Stops the container's main process once this job has finished; Docker's restart policy
    # (Kamal runs every container with unless-stopped) starts it again on the new release.
    def restart
      Thread.new do
        sleep 5
        Process.kill "TERM", 1
      end
    end

    def scratch = @scratch ||= self.class.releases.join(".download-#{@upgrade.id}").tap { FileUtils.mkdir_p it }
end
