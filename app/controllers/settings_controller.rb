# The gear: whoever manages settings lands on Setup until its required steps are done, then
# Appearance; everyone else on their own account.
class SettingsController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "the settings menu in the browser"

  def show
    return redirect_to(settings_account_path) unless can?(:manage_settings)

    redirect_to Setup.new(current_user).complete? ? settings_appearance_path : settings_setup_path
  end
end
