class Users::AvatarsController < ApplicationController
  allow_unauthenticated_access only: :show
  allow_staff
  agent_exempt :show, reason: "an avatar image"

  before_action :set_user

  def show
    if stale? @user, cache_control: cache_control
      render formats: :svg
    end
  end

  private
    def set_user
      @user = User.find(params[:user_id])
    end

    def cache_control
      if @user == Current.user
        {}
      else
        { max_age: 30.minutes, stale_while_revalidate: 1.week }
      end
    end
end
