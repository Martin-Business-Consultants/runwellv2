module Quickbooks
  # A client linked to a QuickBooks customer, by id. Linked by hand, created from Runwell, or
  # matched by the sync on an exact name; never guessed after that.
  class Customer < ::ApplicationRecord
    self.table_name = "quickbooks_customers"

    belongs_to :client, class_name: "::Client"

    validates :qbo_id, presence: true, uniqueness: { message: "is already linked to another client" }

    def self.for(client) = find_by(client: client)
  end
end
