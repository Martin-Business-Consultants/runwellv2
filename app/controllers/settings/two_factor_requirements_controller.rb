# Settings > People: require two-factor sign-in of everyone on the team. Anyone without it is
# sent to set it up on their next page (Authentication#require_two_factor_setup).
class Settings::TwoFactorRequirementsController < ApplicationController
  require_permission :manage_people
  # An owner who just required it can still change their mind before setting up their own.
  skip_before_action :require_two_factor_setup
  agent_exempt :update, reason: "sign-in security is changed by a person in the browser"

  def update
    required = params.dig(:setting, :require_two_factor) == "1"
    Setting.current.update!(require_two_factor: required)
    Setting.current.record_event!("settings.two_factor_required", payload: { required: required })
    redirect_to settings_people_path, notice: required ? "Two-factor sign-in is now required. Anyone without it sets it up on their next page." : "Two-factor sign-in is optional again."
  end
end
