# Settings > AI > Test: one short question to the provider, through the same path as every chat,
# with what it said (or why it failed) kept for the page.
class AiTestJob < ApplicationJob
  def perform
    setting = Setting.current
    started = Time.current
    chat = AiChat.start!(user: User.people.find_by(role: "owner") || User.people.first, purpose: "suggestion", fast: true)
    reply = chat.ask("Reply with the single word: ready")
    setting.update!(ai_test: { "ok_at" => Time.current.iso8601, "model" => chat.model_id, "reply" => reply.content.to_s.truncate(80), "seconds" => (Time.current - started).round(1) })
  rescue => error
    setting.update!(ai_test: { "error" => "#{error.class.name.demodulize}: #{error.message}".truncate(300), "failed_at" => Time.current.iso8601 })
  end
end
