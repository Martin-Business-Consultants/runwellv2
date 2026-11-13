class Notifications::BulkReadingsController < ApplicationController
  allow_staff
  agent_tool :mark_all_notifications_read, on: :create, title: "Mark all notifications read"

  def create
    Current.user.person.notifications.unread.read_all

    if from_tray?
      # The bell's menu, emptied in place: the refresh read_all broadcasts skips the tab that asked.
      render turbo_stream: turbo_stream.update("notifications", helpers.tag.data(hidden: true, value: 0, data: { badge_target: "total" }))
    elsif request.format.turbo_stream?
      render turbo_stream: turbo_stream.replace("notifications_lists", partial: "notifications/index/lists",
        locals: { unread: Notification.none, read: Current.user.person.notifications.read.ordered.preloaded.limit(100) })
    else
      redirect_to notifications_path
    end
  end

  private
    def from_tray?
      params[:from_tray]
    end
end
