# One update of this install to a newer release, started by an owner from Settings > Updates.
# How it happens depends on how the install runs (`Upgrade.via`):
#
#   github  a Docker install deployed with Kamal: starts the repository's Deploy workflow
#           (.github/workflows/deploy.yml) for this install's destination (Upgrade::Github)
#   local   a plain install (bin/install): runs bin/update with the release's tag in the
#           background, which restarts Puma when it's done (Upgrade::Local)
#   manual  neither is set up: Settings > Updates shows the command to run instead
#
# RUNWELL_UPDATES picks one; left unset, a checkout with a .env is local, and a Docker install
# with RUNWELL_GITHUB_TOKEN is github. It succeeds when this install boots on the new version;
# a failed run, or no word within TIMEOUT, fails it. The old version keeps running meanwhile.
class Upgrade < ApplicationRecord
  class Refused < StandardError; end

  VIAS = %w[github local manual].freeze
  STATUSES = %w[running succeeded failed].freeze
  TIMEOUT = 45.minutes

  belongs_to :requested_by, class_name: "User"

  validates :via, inclusion: { in: VIAS - %w[manual] }
  validates :status, inclusion: { in: STATUSES }

  scope :running, -> { where(status: "running") }
  scope :ordered, -> { order(created_at: :desc) }

  def self.via
    configured = ENV["RUNWELL_UPDATES"].presence
    return configured if VIAS.include?(configured)

    if Rails.root.join(".git").exist? && Rails.root.join(".env").exist? then "local"
    elsif Release::Github.token then "github"
    else "manual"
    end
  end

  def self.available? = via == "local" || (via == "github" && Release::Github.token.present?)

  def self.current = running.ordered.first

  # Updates the install to the release, as the person who asked. Refuses when that release
  # isn't newer, updating isn't set up, or an update is already running.
  def self.start!(release, by:)
    raise Refused, "Updating from here isn't set up on this install: see Settings > Updates." unless available?
    raise Refused, "There's no newer release to update to." unless release&.newer?
    raise Refused, "An update to #{current.to_version} is already running." if current

    create!(requested_by: by, from_version: Runwell::VERSION, to_version: release.version, via: via).tap(&:start)
  end

  # Settles running updates: done once this install runs the new version, failed when the run
  # failed or went quiet. Called on Settings > Updates and nightly.
  def self.reconcile = running.find_each(&:reconcile!)

  def start
    runner.start
  rescue Release::Github::Error, SystemCallError => error
    fail! error.message
  end

  def reconcile!
    if Gem::Version.new(Runwell::VERSION) >= Gem::Version.new(to_version)
      update!(status: "succeeded", finished_at: Time.current, message: nil)
    elsif created_at < TIMEOUT.ago
      fail! "No word after #{TIMEOUT.inspect}. #{runner.where_to_look}"
    else
      runner.check
    end
  rescue Release::Github::Error => error
    Rails.error.report(error, context: { upgrade: id })
  end

  def fail!(message)
    update!(status: "failed", finished_at: Time.current, message: message)
  end

  def running? = status == "running"
  def succeeded? = status == "succeeded"
  def failed? = status == "failed"

  def tag = "v#{to_version}"

  def runner = { "github" => Upgrade::Github, "local" => Upgrade::Local }.fetch(via).new(self)
end
