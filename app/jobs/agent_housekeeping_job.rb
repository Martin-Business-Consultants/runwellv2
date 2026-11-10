# Nightly: forgets agent calls and idempotency keys past keeping, one-call assistant tokens, and
# portal sessions gone idle.
class AgentHousekeepingJob < ApplicationJob
  def perform
    AgentCall.prune
    AgentIdempotencyKey.prune
    AccessToken.prune_assistants
    # Portal sessions nobody has used in three months (Portal::BaseController ends them on sight too).
    Session.where(user_id: Contact.select(:id)).where(updated_at: ...Contact::PORTAL_SESSION_IDLE.ago).delete_all
  end
end
