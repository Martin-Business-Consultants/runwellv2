require "net/http"

module Qa
  # Loads a check's page and answers its "appears on it" and "never appears on it"
  # expectations: the phone number in the header, the price on the thank-you page, the other
  # market's number that must never show. The page's text and its HTML are both searched, so a
  # number in a tel: link or a price in the page's data counts too. A page that doesn't load
  # fails every one of them.
  class PageFetch
    TIMEOUT = 15
    REDIRECTS = 5

    def initialize(check)
      @check = check
    end

    def call(user: nil, source: "page")
      expectations = @check.fetchable_expectations
      return if expectations.empty?

      status, html, error = fetch(@check.url)
      text = html && Nokogiri::HTML(html).tap { it.css("script, style").each(&:remove) }.text.squish
      answers = expectations.to_h do |expectation|
        [ expectation.key, answer(expectation, status, html, text, error) ]
      end
      Run.record(check: @check, answers: answers, source: source, user: user, reporter: ("Nightly page check" unless user), http_status: status,
        notes: ("#{@check.url} returned #{status || error}" unless status == 200))
    end

    private
      def answer(expectation, status, html, text, error)
        return { "verdict" => "fail", "actual" => "The page didn’t load (#{status || error})" } unless status == 200

        found = Matcher.found?(expectation.expected, text) || Matcher.found?(expectation.expected, html)
        passed = expectation.match == "includes" ? found : !found
        return { "verdict" => "pass", "actual" => ("Not on the page" if expectation.match == "excludes") } if passed

        { "verdict" => "fail", "actual" => expectation.match == "includes" ? missing(expectation, text) : "It’s on the page" }
      end

      # For a missing phone number, the numbers the page shows instead.
      def missing(expectation, text)
        return "Not on the page" unless Matcher.phone?(expectation.expected)

        numbers = text.scan(/(?<!\d)(?:\+?1[\s.\-]?)?\(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}(?!\d)/).uniq.first(5)
        numbers.any? ? "Not on the page. Numbers it shows: #{numbers.join(", ")}" : "Not on the page, and no phone number is"
      end

      def fetch(url, redirects = REDIRECTS)
        uri = URI.parse(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
          http.get(uri.request_uri, "User-Agent" => "Runwell QA", "Accept" => "text/html")
        end
        if response.is_a?(Net::HTTPRedirection) && redirects.positive? && response["location"]
          return fetch(URI.join(url, response["location"]).to_s, redirects - 1)
        end

        [ response.code.to_i, response.body.to_s.force_encoding("UTF-8").scrub ]
      rescue StandardError => e
        [ nil, nil, "#{e.class.name.demodulize}: #{e.message.truncate(100)}" ]
      end
  end
end
