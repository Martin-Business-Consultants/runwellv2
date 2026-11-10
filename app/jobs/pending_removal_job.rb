# A batch of removals come due (PendingRemoval): the records go, unless their removal was undone.
class PendingRemovalJob < ApplicationJob
  def perform(batch) = PendingRemoval.carry_out(batch)
end
