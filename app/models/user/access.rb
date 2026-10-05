# What an owner does about someone's way in (Settings > People > a person): their name and address,
# a new password or an emailed link to choose one, signing them out everywhere, and cutting off the
# apps they've connected. Each is a security event in the audit log (Event::SECURITY_SUBJECTS), and
# a new password or address signs them out, so whoever had the old one is out too.
module User::Access
  extend ActiveSupport::Concern

  included do
    after_update :record_profile_change, if: -> { !agent? && (saved_change_to_name? || saved_change_to_email_address?) }
  end

  # An owner sets it for them (someone who can't get email, or is locked out).
  def set_password!(password, confirmation)
    transaction do
      update!(password: password, password_confirmation: confirmation)
      sessions.destroy_all
      record_event!("user.password_set")
    end
  end

  # The same email "forgot password" sends, from an owner.
  def send_password_reset!
    PasswordsMailer.reset(self).deliver_later
    record_event!("user.password_reset_sent")
  end

  def sign_out_everywhere!
    count = sessions.count
    sessions.destroy_all
    record_event!("user.signed_out_everywhere", payload: { sessions: count })
  end

  # Every app and script they've connected (personal tokens and OAuth), revoked; they connect again
  # to keep using one.
  def revoke_connections!
    tokens = access_tokens.live.where.not(kind: "assistant").to_a
    tokens.each(&:revoke!)
    record_event!("user.connections_revoked", payload: { tokens: tokens.size })
  end

  private
    def record_profile_change
      changed = saved_changes.slice("name", "email_address").transform_values(&:first)
      sessions.destroy_all if changed.key?("email_address") && Current.user != self
      record_event!("user.profile_changed", payload: { changed: changed.keys })
    end
end
