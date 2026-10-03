# Settings > Updates: the version this install runs, the newest release, and the button that
# updates to it (Upgrade). Past updates and how each went are listed below.
class Settings::UpdatesController < Settings::BaseController
  agent_tool :show_updates, on: :show, title: "Show this install's version, the newest release and past updates"
  agent_tool :update_runwell, on: :create, title: "Update Runwell to the newest release",
    description: "Starts updating this install to the newest release that show_updates lists. It backs up the databases, migrates and restarts; show_updates says how it went.",
    confirm: "The whole install updates to the newest release and restarts: it's unavailable for a minute or two."

  def show
    Upgrade.reconcile
    @release = Release.latest
    @upgrade = Upgrade.current
    @upgrades = Upgrade.ordered.includes(:requested_by).limit(10)
    @failed_count = Upgrade.failed.count
  end

  def create
    upgrade = Upgrade.start!(Release.latest, by: Current.user)
    redirect_to settings_updates_path, notice: "Updating to #{upgrade.to_version}. Runwell restarts when it's done; this page shows how it went."
  rescue Upgrade::Refused => error
    redirect_to settings_updates_path, alert: error.message
  end
end
