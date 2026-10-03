# Sends Settings > Email's test message and keeps how it went (Setting#test_email: to,
# requested_at, then sent_at or the mail server's error), which the page shows.
class TestEmailJob < ApplicationJob
  def self.send_later(to)
    Setting.current.update!(test_email: { "to" => to, "requested_at" => Time.current.iso8601 })
    perform_later(to)
  end

  def perform(to)
    TestMessageMailer.check(to: to).deliver_now
    record "sent_at" => Time.current.iso8601
  rescue StandardError => error
    record "error" => error.message
  end

  private
    def record(outcome)
      setting = Setting.first
      setting.update!(test_email: setting.test_email.merge(outcome))
    end
end
