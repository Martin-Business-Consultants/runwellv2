# A browser or installed app a person said may show their notifications (Settings > Your account,
# the push controller): where to push (its endpoint) and the keys to encrypt for it. A mention
# notifies each of their subscriptions (Notification, PushNotificationJob) beside the email; one the
# push service says is gone (unsubscribed, expired) is deleted. Staff only: contacts have no
# notifications. Kept out of exports (Export::SKIPPED_TABLES).
class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh_key, :auth_key, presence: true

  # Sends one message: true when the push service took it; false when it says the subscription is
  # gone, which deletes it; nil when it couldn't be reached or refused for another reason (kept, and
  # logged: one device's trouble never stops the others').
  def push(payload)
    keys = Setting.current.push_keys
    WebPush.payload_send(message: payload.to_json, endpoint: endpoint, p256dh: p256dh_key, auth: auth_key, ttl: 1.day.to_i, urgency: "normal",
      vapid: { subject: "mailto:#{::Mail::Address.new(Setting.current.mail_sender).address}", public_key: keys[:public_key], private_key: keys[:private_key] })
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
    destroy
    false
  rescue WebPush::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => error
    Rails.logger.warn("Push to #{URI(endpoint).host} failed: #{error.class}: #{error.message}")
    nil
  end
end
