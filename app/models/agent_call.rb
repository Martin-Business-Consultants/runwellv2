# One tool call an agent made with a token: which tool, how it went and how long it took. The
# token's person (and an owner, for every token) sees them in Connected apps; kept 90 days.
class AgentCall < ApplicationRecord
  KEPT = 90.days

  belongs_to :access_token

  scope :recent, -> { order(created_at: :desc) }

  def self.record!(token, tool:, body:, started_at:)
    create!(access_token: token, tool: tool, status: body["status"].to_s, code: body["code"],
      summary: body["summary"].to_s.truncate(250).presence, duration_ms: ((Time.current - started_at) * 1000).round)
  end
end
