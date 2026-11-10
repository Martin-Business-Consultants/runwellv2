# A notification pushed to each browser or installed app its person switched on (PushSubscription):
# who mentioned them and the words, its address (opening it reads it, notifications#show), and how
# many are unread, for the app's badge. A subscription the push service says is gone is deleted.
class PushNotificationJob < ApplicationJob
  include ActionView::Helpers::TextHelper

  def perform(notification)
    mention = notification.source
    payload = {
      title: "#{mention.mentioner.first_name} mentioned you",
      body: truncate(mention.source.mentionable_content.to_s.squish, length: 140),
      url: Rails.application.routes.url_helpers.notification_path(notification),
      tag: "notification-#{notification.id}",
      unread: notification.user.notifications.unread.count
    }
    notification.user.push_subscriptions.find_each { it.push(payload) }
  end
end
