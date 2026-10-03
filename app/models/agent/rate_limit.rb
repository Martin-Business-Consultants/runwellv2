# How many tool calls one token may make a minute (RUNWELL_AGENT_RATE_LIMIT, 120 unless set), so a
# runaway loop in someone's bot can't take the install down. Counted in the cache.
module Agent
  module RateLimit
    def self.limit = ENV.fetch("RUNWELL_AGENT_RATE_LIMIT", 120).to_i

    # Counts this call; true once the token is over the limit for the current minute.
    def self.exceeded?(token)
      return false unless token && limit.positive?

      key = "agent-rate:#{token.id}:#{Time.current.to_i / 60}"
      count = Rails.cache.increment(key, 1, expires_in: 2.minutes)
      count.to_i > limit
    end

    def self.retry_after = 60 - (Time.current.to_i % 60)
  end
end
