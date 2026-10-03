# Settings > Your account > Two-factor sign-in, for everyone. Setting it up shows a QR code for
# an authenticator app (the secret waits in the session until a code from it checks out), then
# the recovery codes, once. Turning it off asks for the password, and isn't offered while the
# install requires it. Agents can't touch it: it guards the browser, not tokens.
class Settings::TwoFactorsController < ApplicationController
  allow_staff
  skip_before_action :require_two_factor_setup, only: %i[new create]
  agent_exempt :create, :destroy, reason: "two-factor sign-in is set up by a person in the browser"

  def new
    return redirect_to(settings_account_path, notice: "Two-factor sign-in is already on.") if Current.user.two_factor?

    @secret = session[:pending_otp_secret] ||= User.new_otp_secret
    @qr_code = RQRCode::QRCode.new(Current.user.otp_provisioning_uri(@secret)).as_svg(module_size: 4, use_path: true, viewbox: true, svg_attributes: { class: "two-factor__qr", role: "img", "aria-label": "QR code for your authenticator app" }).html_safe
  end

  def create
    secret = session[:pending_otp_secret]
    return redirect_to(new_settings_two_factor_path) unless secret

    if (@recovery_codes = Current.user.enable_two_factor!(secret, params[:code]))
      session.delete(:pending_otp_secret)
      flash.now[:notice] = "Two-factor sign-in is on."
      render :recovery_codes
    else
      redirect_to new_settings_two_factor_path, alert: "That code didn’t match. Check your phone’s clock and try the newest code."
    end
  end

  def destroy
    if Setting.current.require_two_factor?
      redirect_to settings_account_path, alert: "This install requires two-factor sign-in, so it stays on."
    elsif Current.user.authenticate(params[:password].to_s)
      Current.user.disable_two_factor!
      redirect_to settings_account_path, notice: "Two-factor sign-in is off."
    else
      redirect_to settings_account_path, alert: "That password isn’t right."
    end
  end
end
