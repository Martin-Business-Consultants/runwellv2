module Cloudflare
  # A Runwell plugin for an install behind Cloudflare's proxy. With it on, a request that
  # arrived through Cloudflare carries the visitor's own address (from CF-Connecting-IP, trusted
  # only when the connection really came from a Cloudflare range) and counts as https when
  # Cloudflare received it over https, so approval evidence and portal sessions record the
  # right address and ASSUME_SSL isn't needed. The ranges are Cloudflare's published lists,
  # bundled and refreshed nightly. No tables.
  class Engine < ::Rails::Engine
    # Before ActionDispatch::SSL (which redirects http) and RemoteIp (which reads the headers).
    initializer "cloudflare.middleware" do |app|
      if app.config.force_ssl
        app.middleware.insert_before ActionDispatch::SSL, Cloudflare::Middleware
      else
        app.middleware.insert_before ActionDispatch::RemoteIp, Cloudflare::Middleware
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :cloudflare, name: "Cloudflare", version: Cloudflare::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.1.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-cloudflare",
        description: "For an install behind Cloudflare’s proxy: records the visitor’s real address instead of Cloudflare’s, and treats a request Cloudflare received over https as https, so nothing else has to assume it."
      Runwell::Plugins.nightly :cloudflare, -> { Cloudflare::Ranges.refresh! }
    end
  end
end
