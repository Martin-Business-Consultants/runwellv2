class Notifications::BulkReadingsController < ApplicationController
  allow_staff
  agent_tool :mark_all_notifications_read, on: :create, title: "Mark all notifications read"

  def create
    Current.user.notifications.unread.read_all

    if from_tray?
      head :ok
    else
      redirect_to notifications_path
    end
  end

  private
    def from_tray?
      params[:from_tray]
    end
end
