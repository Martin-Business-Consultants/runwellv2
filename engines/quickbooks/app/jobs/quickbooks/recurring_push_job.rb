module Quickbooks
  # Brings a service's recurring invoice into step with its agreement.
  class RecurringPushJob < ::ApplicationJob
    queue_as :default

    def perform(engagement_id)
      engagement = ::Engagement.find(engagement_id)
      Current.source = "quickbooks"
      RecurringBilling.new(engagement).push!
    rescue Api::Error, ArgumentError => e
      RecurringLink.find_by(engagement_id: engagement_id)&.update!(drift: "Couldn’t update QuickBooks: #{e.message}".truncate(250))
    end
  end
end
