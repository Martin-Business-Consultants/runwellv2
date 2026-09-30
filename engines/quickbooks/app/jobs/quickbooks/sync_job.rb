module Quickbooks
  class SyncJob < ::ApplicationJob
    queue_as :default

    def perform
      return unless Runwell::Plugins.enabled?(:quickbooks) && Connection.ready?

      Current.source = "quickbooks"
      Sync.new.run!
    rescue Api::Error => e
      Rails.logger.error("[Quickbooks::SyncJob] #{e.message}")
    end
  end
end
