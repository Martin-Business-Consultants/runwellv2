# Checks GitHub for a newer release now, rather than waiting for the nightly check.
class Settings::Updates::ChecksController < Settings::BaseController
  agent_tool :check_for_updates, on: :create, title: "Check for a newer Runwell release now",
    description: "Asks GitHub from a job; show_updates has the answer a few seconds later."

  def create
    Release.check_later
    redirect_to settings_updates_path, notice: "Checking GitHub for a newer release."
  end
end
