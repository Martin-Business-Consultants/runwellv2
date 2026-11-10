class Notification < ApplicationRecord
  include LiveRefreshes
  belongs_to :user
  # Nobody we know, for a request emailed by someone not on file.
  belongs_to :creator, class_name: "User", optional: true
  belongs_to :source, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :ordered, -> { order(read_at: :desc, updated_at: :desc) }
  scope :preloaded, -> { preload(:creator, :source) }

  after_create_commit :deliver_later

  # What it says, whatever it's about: a mention, a client's reply, a request that came in.
  delegate :notifiable_target, :notification_title, :notification_excerpt, to: :source
  alias_method :title, :notification_title
  alias_method :excerpt, :notification_excerpt

  # Why its person got it, for the email's footer.
  def reason
    case source
    when Mention then "someone mentioned you"
    when Note then "you’re on this #{Setting.current.term(:task).downcase}"
    else IntakeShift.exists? ? "you’re on the Intake schedule" : "you take requests on"
    end
  end

  class << self
    # In one statement, then one refresh for each person whose notifications they were.
    def read_all
      users = User.where(id: distinct.select(:user_id)).to_a
      update_all(read_at: Time.current, unread_count: 0, updated_at: Time.current)
      users.each { Turbo::StreamsChannel.broadcast_refresh_to(it, :notifications) }
    end
  end

  def read
    update!(read_at: Time.current, unread_count: 0)
  end

  def unread
    update!(read_at: nil, unread_count: 1)
  end

  def read?
    read_at.present?
  end

  private
    # By email, and pushed to each browser or installed app they switched on (PushSubscription).
    def deliver_later
      NotificationMailer.notification(self).deliver_later
      PushNotificationJob.perform_later(self) if user.push_subscriptions.exists?
    end

    def live_streams = [ [ user, :notifications ] ]
end
