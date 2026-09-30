require "ipaddr"
require "net/http"

module Cloudflare
  # The addresses Cloudflare's proxy connects from. A bundled copy of the published lists,
  # replaced by a fresh copy (kept in the cache) once the nightly refresh has run.
  module Ranges
    PUBLISHED = %w[https://www.cloudflare.com/ips-v4 https://www.cloudflare.com/ips-v6].freeze
    CACHE_KEY = "cloudflare/ranges".freeze

    BUNDLED = %w[
      173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18
      190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13
      104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
      2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
    ].freeze

    class << self
      def include?(address)
        ip = IPAddr.new(address.to_s)
        networks.any? { it.include?(ip) }
      rescue IPAddr::Error
        false
      end

      def list = Rails.cache.read(CACHE_KEY) || BUNDLED

      # Fetches Cloudflare's current lists. Keeps the last good copy if the fetch fails or looks
      # wrong, since a bad list would shut the plugin off for every visitor.
      def refresh!
        fetched = PUBLISHED.flat_map { |url| Net::HTTP.get(URI(url)).lines.map(&:strip).compact_blank }
        raise "Cloudflare returned #{fetched.size} ranges, which can't be right" if fetched.size < 10

        fetched.each { IPAddr.new(it) }
        Rails.cache.write(CACHE_KEY, fetched, expires_in: 30.days)
        fetched
      end

      private
        # Parsed once per distinct list, not once per request.
        def networks
          current = list
          return @networks if @networks_for == current

          @networks = current.map { IPAddr.new(it) }
          @networks_for = current
          @networks
        end
    end
  end
end
