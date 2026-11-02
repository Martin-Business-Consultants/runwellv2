# Someone's password, from their page in Users: email them the link to choose a new one,
# or set one for them (they're signed out everywhere). Your own is changed in Your account.
class Users::PasswordsController < ApplicationController
  require_permission :manage_people
  agent_exempt :create, reason: "a password reset is sent by a person in the browser"
  agent_exempt :update, reason: "passwords are set by a person in the browser, never by an agent"

  before_action :set_person

  def create
    @person.send_password_reset!
    redirect_to user_path(@person), notice: "#{@person.display_name} has an email with a link to choose a new password."
  end

  def update
    @person.set_password!(*params.expect(user: %i[password password_confirmation]).values_at(:password, :password_confirmation))
    redirect_to user_path(@person), notice: "#{@person.display_name}’s password is changed, and they’re signed out everywhere."
  rescue ActiveRecord::RecordInvalid
    redirect_to user_path(@person), alert: @person.errors.full_messages.to_sentence
  end

  private
    def set_person
      @person = User.people.find(params[:user_id])
      redirect_to settings_account_path, alert: "Change your own password in Your account." if @person == current_user
    end
end
