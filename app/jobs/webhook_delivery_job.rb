# Sends one webhook delivery, retrying a failure with growing waits (about a day in all) before
# giving up. Each try is recorded on the delivery.
class WebhookDeliveryJob < ApplicationJob
  retry_on WebhookDelivery::Failed, wait: :polynomially_longer, attempts: 8

  def perform(delivery)
    return unless delivery.webhook_endpoint.active?
    # Its event went with a deleted record: nothing left to send.
    return if delivery.event.nil? && !delivery.ping?

    delivery.deliver!
  end
end
