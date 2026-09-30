module Qa
  # A production deploy (from the Code plugin) changes what's live, so every pass on the
  # client's live checks stops counting until they're tested again. Named by event kind only:
  # QA never depends on the Code plugin being there.
  module Events
    def self.handle(event)
      return unless event.kind == "coding.deployed" && event.subject.is_a?(::Engagement) && Runwell::Plugins.enabled?(:qa)

      Check.active.live.where(client_id: event.subject.client_id).find_each { it.request_retest!(at: event.occurred_at) }
    end
  end
end
