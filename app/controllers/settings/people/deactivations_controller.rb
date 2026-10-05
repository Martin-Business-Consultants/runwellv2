# Deactivating signs a person out and keeps them out; their name stays on their history.
class Settings::People::DeactivationsController < ApplicationController
  require_permission :manage_people
  agent_tool :deactivate_person, on: :create, title: "Deactivate someone", description: "Signs them out and keeps them out; their name stays on their history."
  agent_tool :reactivate_person, on: :destroy, title: "Reactivate someone"

  before_action :set_person

  def create
    return redirect_back_or_to(settings_people_path, alert: "You can’t deactivate yourself.") if @person == current_user

    @person.deactivate!
    redirect_back_or_to settings_people_path, notice: "#{@person.display_name} is deactivated."
  rescue ActiveRecord::RecordInvalid
    redirect_back_or_to settings_people_path, alert: @person.errors.full_messages.to_sentence
  end

  def destroy
    @person.reactivate!
    redirect_back_or_to settings_people_path, notice: "#{@person.display_name} can sign in again."
  end

  private
    def set_person
      @person = User.find(params[:person_id])
    end
end
