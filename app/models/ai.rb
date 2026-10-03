# The install's own AI (Settings > AI), through RubyLLM and its Rails integration: the Ask panel
# (AiChat), and the suggestions on records (AiSuggestion). It works through the same tools agents use over MCP
# (Agent::Catalogue, run by Agent::Dispatch with a short-lived token of the person's), so it can
# do what the person could and nothing more, every write is theirs in the history ("Ted's agent
# via Runwell AI"), and nothing changes until they approve it.
module Ai
  class Unavailable < StandardError; end

  TOKEN_NAME = "Runwell AI"
  RESULT_LIMIT = 12_000 # characters of a tool's answer the model sees

  class << self
    def setting = Setting.current
    def ready? = setting.ai_ready?

    # Whether this person may use it on this record now: switched on, within budget, and not a
    # client the owner keeps out of AI.
    def available_for?(record = nil)
      ready? && !over_budget? && !excluded?(record)
    end

    def excluded?(record)
      client = record.is_a?(Client) ? record : record.try(:client)
      client&.ai_excluded? || false
    end

    # Spend this month in dollars, from RubyLLM's usage records (every chat and suggestion).
    def spent(since: Time.current.beginning_of_month)
      RubyLLM::ActiveRecord::Usage.where(chat_type: "AiChat", created_at: since..).sum(:total_cost).to_d
    end

    def over_budget?
      budget = setting.ai_monthly_budget_cents
      budget.present? && spent * 100 >= budget
    end

    # Runs one agent tool as the person, as an agent over MCP would: a token for this call alone,
    # revoked straight after. Answers the tool's JSON.
    def run_tool(user, tool, arguments)
      token = AccessToken.issue!(user: user, name: TOKEN_NAME, kind: "assistant")
      Agent::Dispatch.new(tool, arguments, token: token.plaintext, base_url: "#{Runwell.protocol}://#{Runwell.host}").call
    ensure
      token&.revoke!
    end

    def trim(value)
      text = value.is_a?(String) ? value : JSON.generate(value)
      text.length > RESULT_LIMIT ? "#{text[0, RESULT_LIMIT]}… (cut short: ask for less, or one record at a time)" : text
    end
  end
end
