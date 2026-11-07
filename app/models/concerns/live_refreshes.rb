# Pages watching a record (turbo_stream_from) refresh in place when it changes, so a teammate's
# change shows up without a reload: Turbo's morphing refresh, debounced in the browser, and the tab
# that made the change ignores its own (the request id). A model says what its change touches with
# live_streams: itself, what it sits on, and the list it's in (:work, :works, :clients).
# Sent straight after the commit (a row in solid_cable in production), and not while importing.
module LiveRefreshes
  extend ActiveSupport::Concern

  included do
    after_commit :refresh_live_streams
  end

  private
    def live_streams = [ self ]

    def refresh_live_streams
      return if Current.source == "import"

      live_streams.compact.uniq.each { Turbo::StreamsChannel.broadcast_refresh_to(*Array(it)) }
    rescue StandardError => error
      Rails.logger.warn("[LiveRefreshes] #{self.class.name} #{id}: #{error.class}: #{error.message}")
    end
end
