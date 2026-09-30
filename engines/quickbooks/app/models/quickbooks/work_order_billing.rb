module Quickbooks
  # Invoicing a fixed-price engagement (a work order, or a project) from Runwell: all of it at
  # once, or a deposit now and the balance later, each sent by QuickBooks with its pay button.
  # The amount is what the client approved: the agreement plus every approved change order.
  # Every reason it can't be billed is answered before anything is created, so a failure is
  # "nothing happened", never half an invoice.
  class WorkOrderBilling
    PORTIONS = %w[full deposit].freeze

    def initialize(engagement, connection = Connection.current)
      @engagement, @connection = engagement, connection
    end

    attr_reader :engagement

    def customer = @customer ||= Customer.for(engagement.client)
    def invoices = Invoice.billed.where(engagement: engagement).recent
    def agreed_cents = engagement.agreed_amount_cents
    def invoiced_cents = invoices.sum(:total_cents)
    def remaining_cents = agreed_cents - invoiced_cents
    def paid_cents = invoices.sum("total_cents - balance_cents")
    def plan = BillingPlan.find_by(engagement: engagement)

    # Why nothing can be invoiced now, or nil.
    def blocker
      return "QuickBooks can’t invoice yet: #{@connection&.blocker || "it isn’t set up"}." unless @connection&.can_invoice?
      return "Only fixed-price work is invoiced here; a service bills through its recurring invoice." if engagement.recurring?
      return "Nothing is approved yet, so there is nothing to invoice." unless engagement.approved?
      return "#{engagement.client.name} isn’t linked to a QuickBooks customer. Link it on the client’s page." unless customer
      return "Everything agreed (#{Money.format(agreed_cents)}) has been invoiced." unless remaining_cents.positive?

      nil
    end

    # Creates and sends the invoice. portion: full (everything not yet invoiced) or deposit
    # (percent of the agreed amount, or amount_cents). With a deposit, send_balance_on_close
    # arms the balance to go to the same contact when the engagement is closed.
    def invoice!(portion:, contact:, percent: nil, amount_cents: nil, send_balance_on_close: false, actor: Current.user)
      raise ArgumentError, blocker if blocker
      raise ArgumentError, "Choose full or deposit." unless PORTIONS.include?(portion)
      raise ArgumentError, "Choose a contact with an email address to send it to." if contact&.email.blank?
      raise ArgumentError, "That contact isn’t #{engagement.client.name}’s." unless contact.client_id == engagement.client_id

      if portion == "deposit"
        raise ArgumentError, "A deposit comes first: this has already been invoiced." if invoices.exists?

        cents = amount_cents.to_i.positive? ? amount_cents.to_i : (agreed_cents * percent.to_f / 100).round
        raise ArgumentError, "A deposit is more than nothing and less than the whole #{Money.format(agreed_cents)}." unless cents.positive? && cents < agreed_cents

        share = (cents * 100.0 / agreed_cents).round
        invoice = create_and_send!([ Lines.line("Deposit (#{share}%): #{title}", cents) ], kind: "deposit", contact: contact, actor: actor)
        BillingPlan.find_or_initialize_by(engagement: engagement)
          .update!(deposit_invoice: invoice, contact: contact, send_balance_on_close: send_balance_on_close, last_error: nil)
        invoice
      else
        invoice = create_and_send!(full_lines, kind: invoices.exists? ? "balance" : "full", contact: contact, actor: actor)
        # Sent by hand, the balance is no longer waiting for the close.
        plan&.update!(balance_invoice: invoice) if plan&.waiting?
        invoice
      end
    end

    # The rest, when a work order with a deposit is closed. Returns nil when nothing is owed.
    def balance!(actor: nil)
      plan = self.plan
      return unless plan&.waiting?
      return plan.update!(send_balance_on_close: false) unless remaining_cents.positive?

      invoice = create_and_send!([ Lines.line("Balance: #{title}", remaining_cents) ], kind: "balance", contact: plan.contact, actor: actor)
      plan.update!(balance_invoice: invoice, last_error: nil)
      invoice
    end

    private
      def title = "#{engagement.ref} #{engagement.title}"

      # The approved items when nothing has been invoiced; else one line for what's left.
      def full_lines
        return [ Lines.line("Balance: #{title}", remaining_cents) ] if invoices.exists?

        engagement.agreed_items.reject { it.price_cents.zero? }.map { Lines.line("#{engagement.ref}: #{it.description}", it.price_cents) }
          .presence || [ Lines.line(title, remaining_cents) ]
      end

      def create_and_send!(lines, kind:, contact:, actor:)
        api = Api.new(@connection)
        created = api.create_invoice(
          "CustomerRef" => { "value" => customer.qbo_id }, "TxnDate" => Date.current.iso8601, "Line" => lines,
          "BillEmail" => { "Address" => contact.email }, "PrivateNote" => "#{Invoice::MEMO}#{engagement.ref}",
          "AllowOnlineACHPayment" => true, "AllowOnlineCreditCardPayment" => true
        )
        api.send_invoice(created["Id"], to: contact.email)
        full = api.invoice(created["Id"]) || created
        invoice = Sync.new(@connection, api).mirror_invoice(full, client: engagement.client, kind: kind, engagement: engagement)
        invoice.update!(created_by: actor, sent_to: contact.email, sent_at: Time.current)
        engagement.record_event!("quickbooks.invoiced", actor: actor, payload: { kind: kind, amount: Money.format(invoice.total_cents), number: invoice.doc_number, to: contact.name })
        invoice
      end
  end
end
