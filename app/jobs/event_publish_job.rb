# Publishes a new event to plugins ("event.runwell", event:) away from the request that made it.
# There's no signed-in person here (Current.user comes from a session or token): subscribers
# read who did it from the event (actor_user, actor) and run with its source.
class EventPublishJob < ApplicationJob
  def perform(event)
    Current.set(source: event.source) do
      ActiveSupport::Notifications.instrument("event.runwell", event: event)
    end
    WebhookEndpoint.dispatch(event)
  end
end
