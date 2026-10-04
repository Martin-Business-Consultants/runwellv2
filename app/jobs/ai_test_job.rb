# Settings > AI > Test: one short question to each model the install uses (the main one, for the
# Ask panel and most suggestions, and the fast one), through the same path as every chat, with
# what each said (or why it failed) kept for the page.
class AiTestJob < ApplicationJob
  def perform
    setting = Setting.current
    owner = User.people.find_by(role: "owner") || User.people.first
    results = [ false, true ].uniq { setting.ai_model_for(fast: it) }.map do |fast|
      model = setting.ai_model_for(fast: fast)
      started = Time.current
      begin
        reply = AiChat.start!(user: owner, purpose: "suggestion", fast: fast).ask("Reply with the single word: ready")
        { "model" => model, "route" => setting.ai_route_name(model), "ok" => true, "reply" => reply.content.to_s.truncate(40), "seconds" => (Time.current - started).round(1) }
      rescue => error
        { "model" => model, "route" => setting.ai_route_name(model), "ok" => false, "error" => "#{error.class.name.demodulize}: #{error.message}".truncate(250) }
      end
    end
    setting.update!(ai_test: { "at" => Time.current.iso8601, "results" => results })
  end
end
