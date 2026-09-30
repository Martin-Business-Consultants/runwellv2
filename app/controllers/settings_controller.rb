# The gear: whoever manages settings lands on Appearance; everyone else has Help.
class SettingsController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "the settings menu in the browser"

  def show
    redirect_to can?(:manage_settings) ? settings_appearance_path : settings_help_path
  end
end
