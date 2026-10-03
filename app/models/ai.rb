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

    # The portal assistant: switched on for clients, within budget, and this client not kept out.
    def portal_available_for?(contact)
setting.ai_portal? && ready? && !over_budget? && !contact.client.ai_excluded?
    end

    def excluded?(record)
      record = record.subject if record.is_a?(Note)
      client = record.is_a?(Client) ? record : (record.try(:client) || record.try(:engagement)&.client)
      client&.ai_excluded? || false
    end

    # Spend this month in dollars, from RubyLLM's usage records (every chat and suggestion).
    def spent(since: Time.current.beginning_of_month)
      RubyLLM::ActiveRecord::Usage.where(chat_type: "AiChat", created_at: since..).sum(:total_cost).to_d
    end

    # Checked once a request (Current), since every card on a page asks.
    def over_budget?
      return Current.ai_over_budget unless Current.ai_over_budget.nil?

      budget = setting.ai_monthly_budget_cents
      Current.ai_over_budget = budget.present? && spent * 100 >= budget
    end

    # Runs one agent tool as the person, as an agent over MCP would: a token for this call alone,
    # revoked straight after. Answers the tool's JSON.
    def run_tool(user, tool, arguments)
      token = AccessToken.issue!(user: user, name: TOKEN_NAME, kind: "assistant")
      Agent::Dispatch.new(tool, arguments, token: token.plaintext, base_url: "#{Runwell.protocol}://#{Runwell.host}").call
    ensure
      token&.revoke!
    end

    # The same for a client's contact in the portal: their own token, so it reaches only what
    # their portal shows.
    def run_portal_tool(contact, tool, arguments)
      token = AccessToken.issue!(contact: contact, name: TOKEN_NAME, kind: "assistant")
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
