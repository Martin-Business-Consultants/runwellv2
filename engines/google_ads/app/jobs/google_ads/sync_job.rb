# Pull Google Ads spend into Runwell: nightly (Runwell::Plugins.nightly), after connecting,
# and from "Sync now".
module GoogleAds
  class SyncJob < ApplicationJob
    # Google being briefly unavailable is not a reason to leave a client's page a day stale.
    retry_on GoogleAds::Client::TransientError, wait: :polynomially_longer, attempts: 4

    def perform
      connection = Connection.current
      return unless connection&.connected?

      summary = Sync.new(connection).call
      Rails.logger.info("[GoogleAds::SyncJob] #{summary.inspect}")
    rescue GoogleAds::Client::AuthError => e
      # The grant is gone or the developer token was rejected. Saying so on the settings page
      # is the only thing that gets it fixed.
      Rails.logger.error("[GoogleAds::SyncJob] auth: #{e.message}")
      Connection.current&.note_error!(e.message)
    end
  end
end
