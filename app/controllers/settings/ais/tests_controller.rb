# Settings > AI > Test: asks the provider for a one-word answer from a job (AiTestJob), so the
# page never waits on it; the page reloads until the answer or the error is in.
class Settings::Ais::TestsController < Settings::BaseController
  agent_exempt :create, reason: "checking the AI provider from the browser"

  def create
    Setting.current.update!(ai_test: { "requested_at" => Time.current.iso8601 })
    AiTestJob.perform_later
    redirect_to settings_ai_path(anchor: "test")
  end
end
