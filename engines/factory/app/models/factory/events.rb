module Factory
  # What the core's events set off here ("event.runwell"): when a client approves an agreement
  # and the factory queues on approval, every piece of that engagement's work an agent can take
  # is queued, attributed to whoever recorded the approval.
  module Events
    def self.handle(event)
      return unless Runwell::Plugins.enabled?(:factory) && event.kind == "agreement.approved" && event.subject.is_a?(::Engagement)
      return unless Policy.current.queue_on_approval

      queue_ready(event.subject, by: event.actor_user, source: event.source)
    end

    def self.queue_ready(engagement, by:, source: Current.source || "app")
      engagement.todos.open.reject { Item.exists?(todo: it) }.select { Readiness.new(it).ready? }
        .each { Item.queue!(it, by: by, source: source) }
    end
  end
end
