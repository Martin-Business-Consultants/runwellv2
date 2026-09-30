module Quickbooks
  # Money received against an invoice. A QuickBooks payment can settle several invoices, so it
  # arrives as one row per invoice it touches.
  class Payment < ::ApplicationRecord
    self.table_name = "quickbooks_payments"

    belongs_to :invoice
  end
end
