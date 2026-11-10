# The install's VAPID keys, which sign the notifications it pushes to people's browsers and
# installed apps (PushSubscription). Made the first time they're needed, one pair per install; the
# private key is encrypted, and exports drop it (its name matches Export::SECRET_COLUMNS).
module Setting::Push
  extend ActiveSupport::Concern

  included do
    encrypts :push_private_key
  end

  def push_keys
    if push_public_key.blank? || push_private_key.blank?
      key = WebPush.generate_key
      update!(push_public_key: key.public_key, push_private_key: key.private_key)
    end
    { public_key: push_public_key, private_key: push_private_key }
  end
end
