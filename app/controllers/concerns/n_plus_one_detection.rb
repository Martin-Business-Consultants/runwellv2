# Scans each request for N+1 queries in development and test (config/initializers/prosopite.rb).
# A request run inside another (an agent's tool call, dispatched within the MCP request) joins the
# scan already going rather than ending it early.
module NPlusOneDetection
  extend ActiveSupport::Concern

  included do
    around_action :detect_n_plus_one, if: -> { defined?(Prosopite) }
  end

  private
    def detect_n_plus_one
      started = !Prosopite.scan?
      Prosopite.scan if started
      yield
    ensure
      Prosopite.finish if started
    end
end
