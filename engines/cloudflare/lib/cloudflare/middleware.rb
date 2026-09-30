require "ipaddr"

module Cloudflare
  # For a request that came through Cloudflare (the connecting address is one of Cloudflare's,
  # looking past a local proxy such as kamal-proxy), puts the visitor's address where
  # ActionDispatch::RemoteIp will read it and marks the request https when Cloudflare received
  # it that way. Anything else is passed through untouched, so a request that spoofs the
  # Cloudflare headers from elsewhere gains nothing.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if enabled? && (visitor = env["HTTP_CF_CONNECTING_IP"].to_s.strip).present? && Ranges.include?(connecting_address(env))
        env["HTTP_X_FORWARDED_FOR"] = visitor
        env["HTTPS"] = "on" if env["HTTP_CF_VISITOR"].to_s.include?("https")
      end
      @app.call(env)
    end

    private
      # The peer that reached us, or, when that is a local proxy, the last hop it recorded.
      def connecting_address(env)
        peer = env["REMOTE_ADDR"].to_s
        return peer unless local?(peer)

        env["HTTP_X_FORWARDED_FOR"].to_s.split(",").map(&:strip).compact_blank.last || peer
      end

      def local?(address)
        ip = IPAddr.new(address)
        ip.private? || ip.loopback? || ip.link_local?
      rescue IPAddr::Error
        false
      end

      def enabled?
        Runwell::Plugins.enabled?(:cloudflare)
      rescue ActiveRecord::ActiveRecordError
        false
      end
  end
end
