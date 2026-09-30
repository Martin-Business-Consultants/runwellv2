class Notifications::TraysController < ApplicationController
  allow_staff
  agent_exempt :show, reason: "the footer tray in the browser; list_notifications covers it"

  MAX_ENTRIES_LIMIT = 100

  def show
    @notifications = Current.user.notifications.unread.preloaded.ordered.limit(MAX_ENTRIES_LIMIT)
    fresh_when etag: Current.user.notifications
  end
end
