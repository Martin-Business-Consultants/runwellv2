# Reading a Google Ads account, over the REST surface of the Google Ads API.
#
# No gem. The official google-ads-googleads client is a large gRPC dependency
# that exists to make MUTATING an account safe, and Runwell never mutates one —
# it asks a single question ("what did this cost") and renders the answer. Two
# endpoints and Net::HTTP is the whole requirement.
#
# Costs arrive from Google in MICROS — millionths of the account currency. They
# are converted to cents here and nowhere else, because a number that is
# sometimes micros and sometimes cents is off by ten thousand and looks
# plausible either way.
module GoogleAds
  class Client
    require "net/http"
    # Google sunsets an API version roughly yearly, and the URL is the only place
    # it appears. Overridable so a version bump is an env var rather than a
    # deploy — which is the whole point, because the failure mode is total: a
    # sunset version answers EVERY call with an HTML 404 page rather than an API
    # error, so the integration doesn't degrade, it stops.
    #
    # Check the release notes, and nothing else:
    #   https://developers.google.com/google-ads/api/docs/release-notes
    #
    # Specifically, do NOT probe the endpoint to find out. An unauthenticated
    # request looks like it distinguishes live versions from dead ones — 401 for
    # one that exists, 404 for one that doesn't — and it does not. v26 answers
    # an unauthenticated call with 401 and an authenticated one with a 404 page.
    # That false signal is how this shipped pointed at a version that has never
    # existed.
    #
    # Latest as of September 2026: v25 (v25.1, released 2026-08-19).
    VERSION = ENV.fetch("GOOGLE_ADS_API_VERSION", "v25")
    HOST = "https://googleads.googleapis.com"

    class Error < StandardError; end

    # The credential is dead and retrying cannot fix it — the grant was revoked,
    # the developer token is not approved, the manager account doesn't own this
    # customer. The sync writes this onto the connection so the settings page
    # can say to reconnect rather than "try again shortly".
    class AuthError < Error; end

    # Google is busy or briefly unavailable. Worth another go.
    class TransientError < Error; end

    def initialize(connection)
      @connection = connection
      @oauth = Oauth.new(connection)
    end

    attr_reader :connection

    # Run a GAQL query against one customer. Returns an array of plain nested
    # hashes with Google's own camelCase keys, exactly as the wire had them —
    # translating them here would mean a second vocabulary to keep in step with
    # the query strings that ask for them.
    def search(customer_id, gaql)
      digits = self.class.normalize_customer_id(customer_id)
      raise Error, "No Google Ads customer id to query" if digits.blank?

      body = post("/#{VERSION}/customers/#{digits}/googleAds:searchStream", { query: gaql })

      # searchStream answers with an ARRAY of chunks, each holding its own
      # `results`. A single-chunk response is the common case and reading it as
      # the results themselves works right up until an account is big enough to
      # be split, which is exactly the account whose numbers matter.
      Array.wrap(body).flat_map { |chunk| Array(chunk["results"]) }
    end

    # The customer ids this login can reach, digits only. What the settings page
    # offers so an id is picked rather than typed.
    def accessible_customers
      body = get("/#{VERSION}/customers:listAccessibleCustomers")
      Array(body["resourceNames"]).map { |name| name.to_s.split("/").last }
    end

    # The account's own name and currency — what a customer id means to a
    # person. Returns nil when the login cannot reach it, which is a normal
    # answer rather than an error: an MCC lists customers it can no longer open.
    def describe(customer_id)
      row = search(customer_id, <<~GAQL).first
        SELECT customer.id, customer.descriptive_name, customer.currency_code, customer.status
        FROM customer
        LIMIT 1
      GAQL
      return nil if row.nil?

      {
        customer_id: row.dig("customer", "id").to_s,
        name: row.dig("customer", "descriptiveName").to_s.presence,
        currency_code: row.dig("customer", "currencyCode").to_s.presence,
        # ENABLED / SUSPENDED / CANCELED / CLOSED. The closest the reporting API
        # comes to saying a payment failed: Google reports the consequence, not
        # the decline. See GoogleAds::Account.
        status: row.dig("customer", "status").to_s.presence
      }
    rescue Error
      nil
    end

    # Google sends customer ids as 123-456-7890 and people paste them that way;
    # the API only takes digits.
    def self.normalize_customer_id(value) = value.to_s.gsub(/[^0-9]/, "").presence

    # 1234567890 back into 123-456-7890, the form every Google screen shows.
    def self.format_customer_id(value)
      digits = normalize_customer_id(value).to_s
      digits.length == 10 ? digits.gsub(/\A(\d{3})(\d{3})(\d{4})\z/, '\1-\2-\3') : digits
    end

    # Google's int64 fields arrive as JSON STRINGS. `.to_i` on the string is
    # right and `.to_i` on a nil is 0, which is also right — an account with no
    # spend returns no row rather than a zero.
    def self.micros_to_cents(micros) = (micros.to_i / 10_000.0).round

    private

    def post(path, payload)
      uri = URI("#{HOST}#{path}")
      request = Net::HTTP::Post.new(uri)
      apply_headers(request)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      parse(perform(uri, request))
    end

    def get(path)
      uri = URI("#{HOST}#{path}")
      request = Net::HTTP::Get.new(uri)
      apply_headers(request)

      parse(perform(uri, request))
    end

    def apply_headers(request)
      request["Authorization"] = "Bearer #{@oauth.access_token!}"
      request["Accept"] = "application/json"
      # Without this header every call is PERMISSION_DENIED, whatever the token.
      request["developer-token"] = connection.developer_token.to_s
      # Only when operating through a manager account. Sending it when the login
      # IS the advertiser is an error, not a no-op, so it is omitted rather than
      # sent blank.
      login = connection.login_customer_id.presence
      request["login-customer-id"] = login if login
    end

    def perform(uri, request)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 90) do |http|
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED,
           SocketError, OpenSSL::SSL::SSLError => e
      # A network failure is not a bad credential, and classifying it as one is
      # how a momentary blip marks every account "needs reconnecting".
      raise TransientError, "Couldn't reach Google Ads (#{e.class}): #{e.message}"
    end

    def parse(response)
      body = begin
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        {}
      end
      return body if response.is_a?(Net::HTTPSuccess)

      # An error on searchStream arrives wrapped in the same array the results
      # would have been; everywhere else it is a bare object.
      error = (body.is_a?(Array) ? body.first : body).to_h["error"] || {}
      status = error["status"].to_s

      case response.code.to_i
      when 401, 403
        raise AuthError, "Google Ads refused the request (#{status.presence || response.code}) — #{detail_from(error, response)}"
      when 404
        # Google answers a sunset API version with its generic HTML 404 page, so
        # there is no error message to quote and echoing the body puts a page of
        # markup in front of someone. The version is very nearly always the
        # cause, so say that instead.
        raise Error, "Google Ads has no #{VERSION} API — it is sunset, or never existed. " \
                     "Check developers.google.com/google-ads/api/docs/release-notes for the " \
                     "current version and set GOOGLE_ADS_API_VERSION to it."
      when 429, 500, 502, 503, 504
        raise TransientError, "Google Ads is unavailable (#{response.code}) — #{detail_from(error, response)}"
      else
        raise Error, "Google Ads returned #{response.code} — #{detail_from(error, response)}"
      end
    end

    # Google's own message where there is one. Where there isn't, the body is
    # usually an HTML error page, and a few hundred characters of markup tells
    # nobody anything — so it is described rather than quoted.
    def detail_from(error, response)
      return error["message"] if error["message"].present?

      body = response.body.to_s.strip
      return "no details given" if body.empty?
      return "the response was an HTML page, not an API error" if body.start_with?("<")

      body.truncate(300)
    end
  end
end
