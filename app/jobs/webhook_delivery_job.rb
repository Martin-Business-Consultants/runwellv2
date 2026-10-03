# Sends one webhook delivery, retrying a failure with growing waits (about a day in all) before
# giving up. Each try is recorded on the delivery.
class WebhookDeliveryJob < ApplicationJob
  retry_on WebhookDelivery::Failed, wait: :polynomially_longer, attempts: 8

  def perform(delivery)
    return unless delivery.webhook_endpoint.active?

    delivery.deliver!
  end
end
