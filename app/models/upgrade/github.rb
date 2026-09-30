# Updates a Docker install by starting the repository's Deploy workflow for the release's tag
# (.github/workflows/deploy.yml), which runs `kamal deploy` for this install's destination with
# the secrets kept in the matching GitHub environment. The new container backs up the databases
# and migrates on boot; this install then runs the new version, which settles the upgrade.
#
#   RUNWELL_DEPLOY_WORKFLOW     the workflow file (default deploy.yml)
#   RUNWELL_DEPLOY_DESTINATION  the Kamal destination (config/deploy.<name>.yml; blank for
#                               config/deploy.yml)
class Upgrade::Github
  def self.workflow = ENV["RUNWELL_DEPLOY_WORKFLOW"].presence || "deploy.yml"
  def self.destination = ENV["RUNWELL_DEPLOY_DESTINATION"].to_s

  def initialize(upgrade)
    @upgrade = upgrade
  end

  def start
    run = api.post("actions/workflows/#{self.class.workflow}/dispatches", ref: @upgrade.tag, return_run_details: true,
      inputs: { version: @upgrade.tag, destination: self.class.destination, upgrade: marker })
    remember run["workflow_run_id"], run["html_url"] if run["workflow_run_id"]
  end

  # Fails the upgrade when its run finished without deploying. A run that succeeded is left for
  # the new version's boot to settle.
  def check
    find_run unless @upgrade.external_id
    return unless @upgrade.external_id

    run = api.get("actions/runs/#{@upgrade.external_id}")
    return unless run["status"] == "completed" && run["conclusion"] != "success"

    @upgrade.fail! "The deploy on GitHub ended #{run["conclusion"].to_s.tr("_", " ")}. Its log says why."
  end

  def where_to_look = "The deploy's log on GitHub says what happened."

  private
    def api = Release::Github.new

    # Names this install and upgrade in the run's title, so the run can be found again when
    # GitHub doesn't return its id (other installs deploy from the same workflow).
    def marker = "#{ENV.fetch("APP_HOST", "localhost")} ##{@upgrade.id}"

    def find_run
      runs = api.get("actions/workflows/#{self.class.workflow}/runs", event: "workflow_dispatch",
        created: ">=#{(@upgrade.created_at - 1.minute).utc.iso8601}")["workflow_runs"].to_a
      run = runs.find { it["display_title"].to_s.include?("(#{marker})") }
      remember run["id"], run["html_url"] if run
    end

    def remember(id, url)
      @upgrade.update!(external_id: id.to_s, external_url: url)
    end
end
