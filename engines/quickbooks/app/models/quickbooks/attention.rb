module Quickbooks
  # The home page's money: overdue invoices, services whose recurring invoice no longer
  # matches what was agreed, and balances that couldn't be sent.
  module Attention
    def self.items
      Invoice.overdue.includes(:client, :engagement).order(:due_on).to_a +
        RecurringLink.drifting.includes(engagement: :client).to_a +
        BillingPlan.where.not(last_error: nil).includes(engagement: :client).to_a
    end
  end
end
