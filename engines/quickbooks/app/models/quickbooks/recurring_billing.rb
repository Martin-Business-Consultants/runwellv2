module Quickbooks
  # A service's recurring invoice in QuickBooks: made from what the client approved, or an
  # existing template linked to it, then kept in step as revisions are approved and when the
  # service closes. QuickBooks sends each invoice itself, to the contact chosen here.
  class RecurringBilling
    def initialize(engagement, connection = Connection.current)
      @engagement, @connection = engagement, connection
    end

    attr_reader :engagement

    def link = RecurringLink.find_by(engagement: engagement)
    def customer = Customer.for(engagement.client)

    def blocker
      return "QuickBooks can’t bill yet: #{@connection&.blocker || "it isn’t set up"}." unless @connection&.can_invoice?
      return "Only a service bills on a schedule; invoice fixed-price work instead." unless engagement.recurring?
      return "Nothing is approved yet, so there is no amount to bill." unless engagement.approved?
      return "#{engagement.client.name} isn’t linked to a QuickBooks customer. Link it on the client’s page." unless customer

      nil
    end

    # A new template billing the approved amount on the approved cadence from start_on.
    def create!(contact:, start_on:, actor: Current.user)
      raise ArgumentError, blocker if blocker
      raise ArgumentError, "This service already has a recurring invoice." if link
      raise ArgumentError, "Choose a contact with an email address for the invoices." if contact&.email.blank?

      wanted = RecurringLink.new(engagement: engagement).expected
      template = api.save_recurring_template(
        "RecurringInfo" => { "Name" => "#{engagement.ref} #{engagement.title}".truncate(100), "RecurType" => "Automated", "Active" => true,
          "ScheduleInfo" => schedule(start_on.to_date, wanted) },
        "CustomerRef" => { "value" => customer.qbo_id }, "Line" => [ Lines.line(line_text, wanted[:amount_cents]) ],
        "BillEmail" => { "Address" => contact.email }, "EmailStatus" => "NeedToSend", "PrivateNote" => "#{Invoice::MEMO}#{engagement.ref}",
        "AllowOnlineACHPayment" => true, "AllowOnlineCreditCardPayment" => true
      )
      record_link(template, contact: contact, event: "quickbooks.recurring_created", actor: actor)
    end

    # An existing template, when it bills this client's customer.
    def link!(qbo_id, actor: Current.user)
      raise ArgumentError, blocker if blocker
      raise ArgumentError, "This service already has a recurring invoice." if link

      template = api.recurring_template(qbo_id.to_s.strip) or raise ArgumentError, "QuickBooks has no recurring invoice #{qbo_id}."
      unless template.dig("CustomerRef", "value") == customer.qbo_id
        raise ArgumentError, "That recurring invoice bills #{template.dig("CustomerRef", "name")}, not #{engagement.client.name}."
      end
      record_link(template, event: "quickbooks.recurring_linked", actor: actor)
    end

    # Makes QuickBooks match the agreement: the approved amount and cadence, and stopped once
    # the service is closed. Returns the link.
    def push!(actor: nil)
      link = self.link or return
      wanted = link.expected
      template = api.recurring_template(link.qbo_id) or raise Api::Error, "QuickBooks no longer has recurring invoice #{link.qbo_id}."
      template["Line"] = [ Lines.line(line_text, wanted[:amount_cents]) ]
      template["RecurringInfo"]["Active"] = wanted[:active]
      info = template["RecurringInfo"]["ScheduleInfo"] ||= {}
      info.merge!(schedule(Date.parse(info["NextDate"] || info["StartDate"] || Date.current.iso8601), wanted).except("StartDate"))
      saved = api.save_recurring_template(template)
      link.observe!(saved)
      link.update!(pushed_at: Time.current)
      change = wanted[:active] ? "quickbooks.recurring_updated" : "quickbooks.recurring_stopped"
      engagement.record_event!(change, actor: actor, payload: { amount: Money.format(wanted[:amount_cents]), schedule: link.schedule_label })
      link
    end

    private
      def api = @api ||= Api.new(@connection)
      def line_text = "#{engagement.ref} #{engagement.title}"

      def schedule(start_on, wanted)
        info = { "StartDate" => start_on.iso8601, "IntervalType" => wanted[:interval_type], "NumInterval" => wanted[:num_interval] }
        wanted[:interval_type] == "Weekly" ? info.merge("DayOfWeek" => start_on.strftime("%A")) : info.merge("DayOfMonth" => [ start_on.day, 28 ].min)
      end

      def record_link(template, event:, actor:, contact: nil)
        link = RecurringLink.create!(engagement: engagement, contact: contact, qbo_id: template["Id"])
        link.observe!(template)
        engagement.record_event!(event, actor: actor, payload: { name: link.name, amount: Money.format(link.amount_cents), schedule: link.schedule_label })
        link
      end
  end
end
