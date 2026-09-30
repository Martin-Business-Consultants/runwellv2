class Notifications::ReadingsController < ApplicationController
  allow_staff
  agent_tool :mark_notification_read, on: :create, title: "Mark a notification read"
  agent_tool :mark_notification_unread, on: :destroy, title: "Mark a notification unread"

  def create
    @notification = Current.user.notifications.find(params[:notification_id])
    @notification.read
  end

  def destroy
    @notification = Current.user.notifications.find(params[:notification_id])
    @notification.unread
  end
end
