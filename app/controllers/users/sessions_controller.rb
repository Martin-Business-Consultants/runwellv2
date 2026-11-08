# Signing someone out of every browser they're signed in on. They can sign in again; to keep them
# out, deactivate them.
class Users::SessionsController < ApplicationController
  require_permission :manage_people
  browser_only :destroy, reason: "signing someone out is a person's call, in the browser"

  def destroy
    person = User.people.find(params[:user_id])
    return redirect_to(user_path(person), alert: "Sign yourself out from the menu instead.") if person == current_user

    person.sign_out_everywhere!
    redirect_to user_path(person), notice: "#{person.display_name} is signed out everywhere."
  end
end
