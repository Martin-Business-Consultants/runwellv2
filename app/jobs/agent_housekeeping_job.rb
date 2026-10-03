# Nightly: forgets agent calls older than AgentCall::KEPT and idempotency keys older than a day.
class AgentHousekeepingJob < ApplicationJob
  def perform
    AgentCall.where(created_at: ...AgentCall::KEPT.ago).in_batches.delete_all
    AgentIdempotencyKey.where(created_at: ...AgentIdempotencyKey::KEPT.ago).in_batches.delete_all
    # The in-app AI's one-call tokens (Ai.run_tool), once their calls are past keeping.
    AccessToken.where(kind: "assistant").where(created_at: ...AgentCall::KEPT.ago).find_each(&:destroy!)
  end
end
