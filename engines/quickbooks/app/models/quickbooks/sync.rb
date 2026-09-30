module Quickbooks
  # Brings QuickBooks into Runwell: nightly, after connecting, and from "Sync now". Links
  # clients to customers on an exact name, mirrors every linked customer's invoices and
  # payments, and checks each service's recurring template still matches what was agreed.
  # Reads only; the worst a bug here can do is show a stale number.
  class Sync
    def initialize(connection = Connection.current, api = nil)
      @connection = connection
      @api = api
    end

    def run!
      summary = { "customers" => link_customers, "invoices" => 0, "payments" => 0, "recurring" => 0, "errors" => [] }
      Customer.includes(:client).find_each do |customer|
        summary["invoices"] += sync_invoices(customer)
        summary["payments"] += sync_payments(customer)
      rescue Api::Error => e
        summary["errors"] << "#{customer.client.name}: #{e.message}"
      end
      RecurringLink.includes(engagement: :agreement_versions).find_each do |link|
        check(link)
        summary["recurring"] += 1
      rescue Api::Error => e
        summary["errors"] << "#{link.engagement.ref}: #{e.message}"
      end
      @connection.note_sync!(summary)
      summary
    rescue Api::Error => e
      @connection.note_error!(e.message)
      raise
    end

    # An invoice as QuickBooks returned it, written into the mirror. Runwell's own invoices
    # carry their engagement in the memo; recurring ones point at their template.
    def mirror_invoice(payload, client:, kind: nil, engagement: nil)
      invoice = Invoice.find_or_initialize_by(qbo_id: payload["Id"])
      return invoice if invoice.persisted? && invoice.client_id != client.id

      engagement ||= invoice.engagement || engagement_from(payload)
      kind ||= invoice.persisted? ? invoice.kind : (recurring_link(payload) ? "recurring" : "other")
      was_open = invoice.persisted? && invoice.balance_cents.positive?
      invoice.update!(client: client, engagement: engagement, kind: kind, doc_number: payload["DocNumber"],
        txn_date: date(payload["TxnDate"]), due_on: date(payload["DueDate"]),
        total_cents: Lines.cents(payload["TotalAmt"]), balance_cents: Lines.cents(payload["Balance"]),
        voided: payload["PrivateNote"].to_s.start_with?("Voided"), payment_link: payload["InvoiceLink"].presence || invoice.payment_link,
        sync_token: payload["SyncToken"], synced_at: Time.current)
      if was_open && invoice.balance_cents <= 0 && engagement
        engagement.record_event!("quickbooks.paid", source: "quickbooks", payload: { number: invoice.doc_number, amount: Money.format(invoice.total_cents) })
      end
      invoice
    end

    private
      def api = @api ||= Api.new(@connection)

      # Only for clients with no link yet, and only on an exact name: the person who linked
      # one by hand knows which "Acme" is which and this does not.
      def link_customers
        unlinked = ::Client.where.not(id: Customer.select(:client_id)).to_a
        return 0 if unlinked.empty?

        taken = Customer.pluck(:qbo_id).to_set
        by_name = api.customers.reject { taken.include?(it["Id"]) }.index_by { it["DisplayName"].to_s.downcase }
        unlinked.count do |client|
          match = by_name[client.name.downcase] or next false
          Customer.create!(client: client, qbo_id: match["Id"], display_name: match["DisplayName"], email: match.dig("PrimaryEmailAddr", "Address"))
        end
      end

      # A customer's invoices, and any that disappeared from QuickBooks marked voided.
      def sync_invoices(customer)
        payloads = api.query_all("Invoice", where: "CustomerRef = '#{Api.escape(customer.qbo_id)}'")
        payloads.each { |payload| mirror_invoice(payload, client: customer.client) }
        Invoice.where(client: customer.client).where.not(qbo_id: payloads.map { it["Id"] }).update_all(voided: true, balance_cents: 0)
        payloads.size
      end

      def sync_payments(customer)
        api.query_all("Payment", where: "CustomerRef = '#{Api.escape(customer.qbo_id)}'").sum do |payload|
          Array(payload["Line"]).sum do |line|
            linked = Array(line["LinkedTxn"]).find { it["TxnType"] == "Invoice" } or next 0
            invoice = Invoice.find_by(qbo_id: linked["TxnId"]) or next 0
            Payment.find_or_initialize_by(qbo_id: "#{payload["Id"]}-#{linked["TxnId"]}")
              .update!(invoice: invoice, amount_cents: Lines.cents(line["Amount"]), paid_on: date(payload["TxnDate"]) || Date.current,
                method_name: payload.dig("PaymentMethodRef", "name"))
            1
          end
        end
      end

      def check(link)
        template = api.recurring_template(link.qbo_id)
        template ? link.observe!(template) : link.update!(drift: "QuickBooks no longer has this recurring invoice", synced_at: Time.current)
      end

      def engagement_from(payload)
        ref = payload["PrivateNote"].to_s[/#{Invoice::MEMO}(\S+)/o, 1]
        (ref && ::Engagement.find_by(ref: ref)) || recurring_link(payload)&.engagement
      end

      def recurring_link(payload)
        id = payload.dig("RecurDataRef", "value")
        id && RecurringLink.find_by(qbo_id: id)
      end

      def date(value)
        value.present? ? Date.parse(value.to_s) : nil
      rescue Date::Error
        nil
      end
  end
end
