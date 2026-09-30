module Quickbooks
  # A closed work order's balance, armed when its deposit was sent.
  class BalanceJob < ::ApplicationJob
    queue_as :default

    def perform(engagement_id)
      engagement = ::Engagement.find(engagement_id)
      Current.source = "quickbooks"
      WorkOrderBilling.new(engagement).balance!
    rescue Api::Error, ArgumentError => e
      BillingPlan.find_by(engagement_id: engagement_id)&.update!(last_error: e.message)
      engagement&.record_event!("quickbooks.balance_failed", source: "quickbooks", payload: { error: e.message.truncate(200) })
    end
  end
end
