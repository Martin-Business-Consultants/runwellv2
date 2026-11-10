class Notification < ApplicationRecord
  include LiveRefreshes
  belongs_to :user
  belongs_to :creator, class_name: "User"
  belongs_to :source, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :ordered, -> { order(read_at: :desc, updated_at: :desc) }
  scope :preloaded, -> { preload(:creator, source: [ :mentioner, :source ]) }

  after_create_commit :deliver_later

  delegate :notifiable_target, to: :source

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
    def deliver_later
      NotificationMailer.notification(self).deliver_later
    end

    def live_streams = [ [ user, :notifications ] ]
end
