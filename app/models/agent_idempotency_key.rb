# A write an agent sent with an idempotency key, and how it answered. Sent again with the same
# key (a retry after a timeout), the tool answers the same way instead of running twice. Kept a day.
class AgentIdempotencyKey < ApplicationRecord
  KEPT = 1.day

  belongs_to :access_token
end
