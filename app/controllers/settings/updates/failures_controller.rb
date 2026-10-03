# Clears failed updates from Past updates once they've been read, so the list shows what worked.
class Settings::Updates::FailuresController < Settings::BaseController
  agent_tool :clear_failed_updates, on: :destroy, title: "Clear failed updates from this install's past updates"

  def destroy
    count = Upgrade.failed.delete_all
    redirect_to settings_updates_path, notice: count.zero? ? "There were no failed updates to clear." : "Cleared #{helpers.pluralize(count, "failed update")}."
  end
end
