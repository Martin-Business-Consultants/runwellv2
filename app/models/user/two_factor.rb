# Two-factor sign-in: a code from an authenticator app (TOTP, 30 seconds) after the password, or
# one of ten single-use recovery codes when the phone is gone. The secret is encrypted; recovery
# codes are kept only as digests and shown once. A code can't be used twice (otp_last_used_at),
# and one either side of now is accepted for a phone whose clock drifts.
module User::TwoFactor
  extend ActiveSupport::Concern

  ISSUER = "Runwell"
  RECOVERY_CODES = 10

  included do
    encrypts :otp_secret
  end

  class_methods do
    def new_otp_secret = ROTP::Base32.random
  end

  def two_factor? = otp_enabled_at.present?

  # The install requires it (Settings > People) and this person hasn't set it up yet.
  def two_factor_setup_required? = !two_factor? && !agent? && Setting.current.require_two_factor?

  # The otpauth:// address an authenticator app reads from the QR code.
  def otp_provisioning_uri(secret)
    ROTP::TOTP.new(secret, issuer: Runwell.host_set? ? "#{ISSUER} (#{Runwell.host})" : ISSUER).provisioning_uri(email_address)
  end

  # Turns it on once a code from the new secret checks out; answers the recovery codes to show
  # once, or nil when the code is wrong.
  def enable_two_factor!(secret, code)
    return unless (at = self.class.otp_verify(secret, code))

    codes = new_recovery_codes
    update!(otp_secret: secret, otp_enabled_at: Time.current, otp_last_used_at: at, otp_recovery_codes: codes.map { digest(it) })
    sessions.where.not(id: Current.session&.id).destroy_all
    record_event!("user.two_factor_enabled")
    codes
  end

  def disable_two_factor!
    was_on = two_factor?
    update!(otp_secret: nil, otp_enabled_at: nil, otp_last_used_at: nil, otp_recovery_codes: nil)
    record_event!(Current.user == self ? "user.two_factor_disabled" : "user.two_factor_reset") if was_on
  end

  # A code from the app, or a recovery code (used up). True when one of them checks out.
  def verify_second_factor(code)
    return false unless two_factor?

    code = code.to_s.gsub(/[\s-]/, "").downcase
    verify_otp(code) || use_recovery_code(code)
  end

  def regenerate_recovery_codes!
    new_recovery_codes.tap do |codes|
      update!(otp_recovery_codes: codes.map { digest(it) })
      record_event!("user.recovery_codes_renewed")
    end
  end

  def recovery_codes_left = Array(otp_recovery_codes).size

  class_methods do
    # The time the code was made for, or nil.
    def otp_verify(secret, code, after: nil)
      at = ROTP::TOTP.new(secret).verify(code.to_s.gsub(/\s/, ""), drift_behind: 30, drift_ahead: 30, after: after&.to_i)
      Time.at(at) if at
    end
  end

  private
    def verify_otp(code)
      return false unless code.match?(/\A\d{6}\z/)
      return false unless (at = self.class.otp_verify(otp_secret, code, after: otp_last_used_at))

      update_columns(otp_last_used_at: at)
      true
    end

    def use_recovery_code(code)
      digests = Array(otp_recovery_codes)
      return false unless (match = digests.find { ActiveSupport::SecurityUtils.secure_compare(it, digest(code)) })

      update_columns(otp_recovery_codes: digests - [ match ])
      true
    end

    def new_recovery_codes
      Array.new(RECOVERY_CODES) { SecureRandom.alphanumeric(10).downcase.scan(/.{5}/).join("-") }
    end

    def digest(code) = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{id}:#{code.delete("-")}")
end
