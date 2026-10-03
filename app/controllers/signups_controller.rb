class SignupsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_signup_path, alert: "Try again later." }
  before_action :redirect_authenticated_user
  before_action :require_no_users

  layout "public"

  def new
    @start = "business"
    @user = User.new
  end

  def create
    @user = User.new(signup_params)
    @start = params.dig(:signup, :start).presence_in(Setting::STARTS.keys) || "business"

    if @user.save
      Setting.current.apply_start!(@start) if Setting::STARTS.key?(@start)
      start_new_session_for @user, method: "signup"
      redirect_to root_path, notice: "Welcome to Runwell."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def redirect_authenticated_user
      redirect_to root_path if authenticated?
    end

    # Signing up makes the first owner. After that, people join by invitation.
    def require_no_users
      redirect_to new_session_path, alert: "Runwell is invite-only. Ask an owner for an invitation." if User.exists?
    end

    def signup_params
      params.expect signup: %i[ name email_address password ]
    end
end
