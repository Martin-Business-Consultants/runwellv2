# Tells whoever's on the Intake schedule now about what's waiting for them, and sends digests due
# (IntakeShift.deliver): every minute, and as something comes in. One at a time, so nobody hears twice.
class IntakeDeliveryJob < ApplicationJob
  limits_concurrency to: 1, key: "intake_delivery", duration: 5.minutes

  def perform
    IntakeShift.deliver
  end
end
