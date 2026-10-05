# Settings > People: reset someone's two-factor sign-in when they've lost their phone and their
# recovery codes. They sign in with just their password and set it up again (straight away, if
# the install requires it).
class Settings::People::TwoFactorsController < ApplicationController
  require_permission :manage_people
  agent_exempt :destroy, reason: "sign-in security is changed by a person in the browser"

  def destroy
    person = User.people.find(params[:person_id])
    if person == Current.user
      redirect_to settings_account_path, alert: "Turn your own off in Settings › Your account."
    else
      person.disable_two_factor!
      person.sessions.destroy_all
      redirect_back_or_to settings_people_path, notice: "#{person.display_name}’s two-factor sign-in is reset. They’ll set it up again."
    end
  end
end
