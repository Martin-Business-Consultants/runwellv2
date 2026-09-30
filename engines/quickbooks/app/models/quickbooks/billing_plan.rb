module Quickbooks
  # A work order billed in two parts: the deposit already sent, and whether the balance goes
  # out by itself when the work order is closed, to whom.
  class BillingPlan < ::ApplicationRecord
    self.table_name = "quickbooks_billing_plans"

    belongs_to :engagement, class_name: "::Engagement"
    belongs_to :contact, class_name: "::Contact", optional: true
    belongs_to :deposit_invoice, class_name: "Quickbooks::Invoice", optional: true
    belongs_to :balance_invoice, class_name: "Quickbooks::Invoice", optional: true

    scope :waiting, -> { where(send_balance_on_close: true, balance_invoice_id: nil) }

    def waiting? = send_balance_on_close && balance_invoice_id.nil?
  end
end
