# A notification pushed to each browser or installed app its person switched on (PushSubscription):
# what happened (a mention, a client's reply, a request) and the words, its address (opening it reads it, notifications#show), and how
# many are unread, for the app's badge. A subscription the push service says is gone is deleted.
class PushNotificationJob < ApplicationJob
  include ActionView::Helpers::TextHelper

  def perform(notification)
    payload = {
      title: notification.title,
      body: truncate(notification.excerpt.squish, length: 140),
      url: Rails.application.routes.url_helpers.notification_path(notification),
      tag: "notification-#{notification.id}",
      unread: notification.user.notifications.unread.count
    }
    notification.user.push_subscriptions.find_each { it.push(payload) }
  end
end
