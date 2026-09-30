class NotificationMailer < ApplicationMailer
  helper :searches

  def notification(notification)
    @notification = notification
    @mention = notification.source
    mail to: notification.user.email_address, subject: "#{@mention.mentioner.first_name} mentioned you"
  end
end
