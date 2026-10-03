# New recovery codes for two-factor sign-in, shown once; the old ones stop working. Asks for the
# password, since whoever has these can sign in without the phone.
class Settings::TwoFactors::RecoveryCodesController < ApplicationController
  allow_staff
  agent_exempt :create, reason: "recovery codes are shown to a person in the browser"

  def create
    if !Current.user.two_factor?
      redirect_to settings_account_path
    elsif Current.user.authenticate(params[:password].to_s)
      @recovery_codes = Current.user.regenerate_recovery_codes!
      flash.now[:notice] = "New recovery codes. The old ones no longer work."
      render "settings/two_factors/recovery_codes"
    else
      redirect_to settings_account_path, alert: "That password isn’t right."
    end
  end
end
