# The newest published release of Runwell, as GitHub lists it (drafts and prereleases left out).
# Checked nightly (ReleaseCheckJob) and from Settings > Updates, and kept on the settings row,
# so a page never waits on GitHub. Settings > Updates offers it when it's newer than this install.
class Release
  attr_reader :version, :url, :notes, :published_at

  def self.latest
    data = Setting.current.latest_release
    new(data) if data.present?
  end

  # Asks GitHub for the newest release and keeps it. Raises Release::Github::Error when GitHub
  # can't be reached or the repository isn't visible.
  def self.check!
    data = Release::Github.new.get("releases/latest")
    release = new("version" => data["tag_name"].to_s.delete_prefix("v"), "url" => data["html_url"],
                  "notes" => data["body"], "published_at" => data["published_at"])
    Setting.current.update!(latest_release: release.to_h, release_checked_at: Time.current)
    release
  end

  def self.checked_at = Setting.current.release_checked_at

  # Check now: asks from a job (ReleaseCheckNowJob) and the page shows it's under way until the
  # answer or GitHub's error is in. One that hasn't come back in five minutes isn't shown as running.
  def self.check_later
    Setting.current.update!(release_check_requested_at: Time.current, release_check_error: nil)
    ReleaseCheckNowJob.perform_later
  end

  def self.check_pending?
    setting = Setting.current
    requested = setting.release_check_requested_at
    requested.present? && requested > 5.minutes.ago && setting.release_check_error.blank? &&
      (setting.release_checked_at.nil? || setting.release_checked_at < requested)
  end

  def self.check_error = Setting.current.release_check_error

  # Off with RUNWELL_UPDATE_CHECK=false (an install with no way out to GitHub).
  def self.checking? = ENV["RUNWELL_UPDATE_CHECK"] != "false"

  def initialize(data)
    @version = data["version"]
    @url = data["url"]
    @notes = data["notes"]
    @published_at = data["published_at"]&.then { Time.zone.parse(it.to_s) }
  end

  def tag = "v#{version}"

  def newer? = Gem::Version.correct?(version) && Gem::Version.new(version) > Gem::Version.new(Runwell::VERSION)

  def to_h = { "version" => version, "url" => url, "notes" => notes, "published_at" => published_at&.iso8601 }
end
