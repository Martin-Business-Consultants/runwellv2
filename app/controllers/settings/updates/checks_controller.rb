# Checks GitHub for a newer release now, rather than waiting for the nightly check.
class Settings::Updates::ChecksController < Settings::BaseController
  agent_tool :check_for_updates, on: :create, title: "Check for a newer Runwell release now"

  def create
    release = Release.check!

    if release.newer?
      redirect_to settings_updates_path, notice: "Runwell #{release.version} is out. This install runs #{Runwell::VERSION}."
    else
      redirect_to settings_updates_path, notice: "Runwell #{Runwell::VERSION} is the newest release."
    end
  rescue Release::Github::Error => error
    redirect_to settings_updates_path, alert: error.message
  end
end
