# Pausing a connection stops it at once without disconnecting it: every call answers "paused"
# until it's resumed. Your own connections, or anyone's for an owner.
class Settings::ConnectedApps::PausesController < ApplicationController
  allow_staff
  agent_exempt :create, :destroy, reason: "access tokens are managed by a person in the browser"

  before_action :set_token

  def create
    @token.pause!
    redirect_to settings_connected_apps_path, notice: "#{@token.name} is paused: it can’t do anything until you resume it."
  end

  def destroy
    @token.resume!
    redirect_to settings_connected_apps_path, notice: "#{@token.name} is working again."
  end

  private
    def set_token
      tokens = can?(:manage_people) ? AccessToken.live : current_user.access_tokens.live
      @token = tokens.find(params[:connected_app_id])
    end
end
