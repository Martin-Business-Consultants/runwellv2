# Nightly: forgets agent calls and idempotency keys past keeping, and one-call assistant tokens.
class AgentHousekeepingJob < ApplicationJob
  def perform
    AgentCall.prune
    AgentIdempotencyKey.prune
    AccessToken.prune_assistants
  end
end
