# Dismisses the first-run checklist on home for the whole install.
class SetupsController < ApplicationController
  require_permission :manage_settings
  agent_exempt :destroy, reason: "hides a checklist on the home page; nothing for an agent to do"

  def destroy
    Setting.current.update!(setup_dismissed_at: Time.current)
    redirect_to root_path, notice: "Setup checklist hidden. How Runwell works is always in Settings → Help."
  end
end
