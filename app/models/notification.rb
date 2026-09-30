class Notification < ApplicationRecord
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
    def read_all
      all.each(&:read)
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
end
