# A notification by email: a mention, a client's reply on a task, a request that came in.
class NotificationMailer < ApplicationMailer
  def notification(notification)
    @notification = notification
    mail to: notification.user.email_address, subject: notification.title
  end
end
