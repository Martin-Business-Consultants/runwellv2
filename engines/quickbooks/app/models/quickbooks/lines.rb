module Quickbooks
  # QuickBooks takes dollars and wants an Item on every line; the one chosen in Settings >
  # QuickBooks stands behind all of Runwell's lines so each keeps its own wording.
  module Lines
    def self.line(description, cents, item_id: Connection.current.default_item_id)
      { "DetailType" => "SalesItemLineDetail", "Amount" => (cents.to_i / 100.0).round(2), "Description" => description.to_s.truncate(4000),
        "SalesItemLineDetail" => { "ItemRef" => { "value" => item_id } } }
    end

    def self.dollars(cents) = (cents.to_i / 100.0).round(2)
    def self.cents(amount) = (amount.to_f * 100).round
  end
end
