# Preview at http://localhost:3000/rails/mailers/notification_mailer (seeded data, bin/rails db:seed:replant).
class NotificationMailerPreview < ActionMailer::Preview
  def notification = NotificationMailer.notification(Notification.take)
end
