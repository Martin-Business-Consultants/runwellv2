module Quickbooks
  # What the core's events set off here ("event.runwell"): closing a work order sends its
  # armed balance; approving a service's revision, or closing it, brings its recurring invoice
  # into step. The work runs in jobs, after the core's write has committed.
  module Events
    def self.handle(event)
      return unless Runwell::Plugins.enabled?(:quickbooks) && event.subject.is_a?(::Engagement)

      engagement = event.subject
      case event.kind
      when "engagement.closed"
        BalanceJob.perform_later(engagement.id) if BillingPlan.waiting.exists?(engagement: engagement)
        RecurringPushJob.perform_later(engagement.id) if RecurringLink.exists?(engagement: engagement)
      when "agreement.approved"
        RecurringPushJob.perform_later(engagement.id) if engagement.recurring? && RecurringLink.exists?(engagement: engagement)
      end
    end
  end
end
