# Signing someone out of every browser they're signed in on. They can sign in again; to keep them
# out, deactivate them.
class Settings::People::SessionsController < ApplicationController
  require_permission :manage_people
  agent_exempt :destroy, reason: "signing someone out is a person's call, in the browser"

  def destroy
    person = User.people.find(params[:person_id])
    return redirect_to(settings_person_path(person), alert: "Sign yourself out from the menu instead.") if person == current_user

    person.sign_out_everywhere!
    redirect_to settings_person_path(person), notice: "#{person.display_name} is signed out everywhere."
  end
end
