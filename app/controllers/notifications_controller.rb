class NotificationsController < ApplicationController
  allow_staff
  agent_tool :list_notifications, on: :index, title: "List your notifications"
  agent_exempt :show, reason: "opens a notification in the browser; list_notifications and mark_notification_read cover it"

  MAX_UNREAD_NOTIFICATIONS = 500

  def index
    @unread = Current.user.notifications.unread.ordered.preloaded.limit(MAX_UNREAD_NOTIFICATIONS)
    @read = Current.user.notifications.read.ordered.preloaded.limit(100)
  end

  # Fizzy reads a notification when its card opens. Here the target can be any record, so
  # following a notification reads it on the way there.
  def show
    notification = Current.user.notifications.find(params[:id])
    notification.read
    redirect_to helpers.search_result_path(notification.notifiable_target)
  end
end
