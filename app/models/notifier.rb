class Notifier
  attr_reader :source

  class << self
    def for(source)
      case source
      when Mention
        MentionNotifier.new(source)
      end
    end
  end

  def notify
    recipients.sort_by(&:id).map do |recipient|
      Notification.create!(user: recipient, source: source, creator: creator, unread_count: 1)
    end
  end

  private
    def initialize(source)
      @source = source
    end
end
