# The gear: whoever manages settings lands on Address, the first of the install's settings;
# everyone else on their own account.
class SettingsController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "the settings menu in the browser"

  def show
    return redirect_to(settings_account_path) unless can?(:manage_settings)

    redirect_to settings_address_path
  end
end
