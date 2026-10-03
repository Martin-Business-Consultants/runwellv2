# Updates a Docker install in place, the way WordPress updates itself: downloads the release's
# bundle (the app as its image holds it, gems and compiled assets included, built for each
# architecture by .github/workflows/release.yml) into releases/ in the data directory, checks it,
# points releases/current at it and restarts the container. On boot bin/docker-entrypoint runs
# whichever is newer, the image or releases/current, then backs up and migrates as always.
# Deploying a newer image takes over again.
#
# Each bundle carries the Ruby its gems were built for (config/bundled_ruby.rb switches to it), so
# a new Ruby comes this way too. A release that needs other system packages or Debian
# (RUNWELL_BASE in the Dockerfile) can't: it redeploys, through GitHub when the install can
# (Upgrade::Github), else with the command the failure names. Plugins live in the data volume
# too, so they carry over.
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

  def start = install

  # Run by UpgradeJob. A job that runs again after the restart finds the new version running.
  def install
    return @upgrade.reconcile! if Gem::Version.new(Runwell::VERSION) >= Gem::Version.new(@upgrade.to_version)

    return if needs_image?(fetch_manifest)

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

    def fetch_manifest
      JSON.parse(download_to("runwell-#{tag}.json", scratch.join("manifest.json")).read)
    end

    # A bundle that carries its Ruby needs only the same base; an older one, the same Ruby too.
    # When it needs a new image, deploy one through GitHub if this install can, else fail with how.
    def needs_image?(manifest)
      same_ruby = manifest["bundles_ruby"] || manifest["ruby"] == RUBY_VERSION
      return false if same_ruby && manifest["base"].to_s == ENV["RUNWELL_BASE"].to_s

      reason = same_ruby ? "base #{manifest["base"]} (this image has #{ENV["RUNWELL_BASE"]})" : "Ruby #{manifest["ruby"]} (this image has #{RUBY_VERSION})"
      if Release::Github.token.present?
        @upgrade.update!(via: "github", message: "#{tag} needs a new image, for #{reason}: deploying it through GitHub.")
        Upgrade::Github.new(@upgrade).start
        true
      else
        raise Failed, "#{tag} needs a new image, for #{reason}. Redeploy: `kamal deploy` from a checkout of #{tag}, or pull " \
          "ghcr.io/martin-business-consultants/runwell:#{tag.delete_prefix("v")} and recreate the container with the same volume and settings. " \
          "Data and plugins carry over; later updates come this way again."
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

    def restart = Runwell::Restart.later

    def scratch = @scratch ||= self.class.releases.join(".download-#{@upgrade.id}").tap { FileUtils.mkdir_p it }
end
