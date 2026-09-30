module Quickbooks
  # The QuickBooks Online accounting API, as much of it as Runwell uses. Reads (customers,
  # items, invoices, payments, recurring templates, reports) are safe to run on a schedule.
  # The writes are few and each is a named method below, so what Runwell can do to the books
  # is easy to see: create a customer, create and send an invoice, and create, change or stop
  # a recurring invoice template. Nothing deletes, and nothing touches a payment.
  class Api
    require "net/http"

    MINOR_VERSION = 75

    class Error < StandardError; end

    def initialize(connection = Connection.current)
      raise Error, "QuickBooks isn’t connected. Connect it in Settings > QuickBooks." unless connection&.connected?

      @connection = connection
      @oauth = Oauth.new(connection)
    end

    attr_reader :connection

    def self.escape(value) = value.to_s.gsub("'", "\\\\'")

    # QuickBooks' SQL-ish dialect, paged: Intuit caps a page at 1000 whatever you ask for.
    def query_all(entity, where: nil, page_size: 200)
      results = []
      position = 1
      loop do
        statement = [ "SELECT * FROM #{entity}", ("WHERE #{where}" if where), "STARTPOSITION #{position} MAXRESULTS #{page_size}" ].compact.join(" ")
        page = get("/query", query: statement).dig("QueryResponse", entity) || []
        results.concat(page)
        break if page.size < page_size

        position += page_size
      end
      results
    end

    def company = get("/companyinfo/#{connection.realm_id}")["CompanyInfo"]
    def customers = query_all("Customer", where: "Active = true")
    def items = query_all("Item", where: "Active = true AND Type IN ('Service', 'NonInventory')")
    def recurring_templates = query_all("RecurringTransaction").filter_map { it["Invoice"] }

    # The hosted payment link is only returned when asked for by name, and only when the
    # company has online payments switched on.
    def invoice(id) = get("/invoice/#{id}", include: "invoiceLink")["Invoice"]
    def recurring_template(id) = get("/recurringtransaction/#{id}").dig("RecurringTransaction", "Invoice")

    def report(name, **params) = get("/reports/#{name}", **params)

    # --- writes ---------------------------------------------------------------------------

    def create_customer(payload) = post("/customer", payload)["Customer"]
    def create_invoice(payload) = post("/invoice", payload)["Invoice"]

    # QuickBooks emails the invoice, with its pay button, from the company's own address.
    def send_invoice(id, to:) = post("/invoice/#{id}/send", nil, sendTo: to)["Invoice"]

    # A recurring template is an Invoice with RecurringInfo. An update is a full replace, so it
    # takes the Id and SyncToken of the version it changes.
    def save_recurring_template(invoice) = post("/recurringtransaction", { "Invoice" => invoice }).dig("RecurringTransaction", "Invoice")

    private
      def get(path, **query)
        uri = URI("#{connection.api_host}/v3/company/#{connection.realm_id}#{path}")
        uri.query = query.compact.merge(minorversion: MINOR_VERSION).to_query
        request(Net::HTTP::Get.new(uri))
      end

      def post(path, payload, **query)
        uri = URI("#{connection.api_host}/v3/company/#{connection.realm_id}#{path}")
        uri.query = query.compact.merge(minorversion: MINOR_VERSION).to_query
        request = Net::HTTP::Post.new(uri)
        if payload
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(payload)
        else
          request["Content-Type"] = "application/octet-stream"
        end
        request(request)
      end

      def request(request)
        request["Authorization"] = "Bearer #{@oauth.access_token!}"
        request["Accept"] = "application/json"
        uri = request.uri
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) { it.request(request) }
        body = begin
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          {}
        end
        return body if response.is_a?(Net::HTTPSuccess)

        fault = body.dig("Fault", "Error")&.first
        raise Error, "QuickBooks returned #{response.code}: #{fault ? "#{fault["Message"]}. #{fault["Detail"]}" : response.body.to_s.truncate(300)}"
      rescue Oauth::Error => e
        raise Error, e.message
      end
  end
end
