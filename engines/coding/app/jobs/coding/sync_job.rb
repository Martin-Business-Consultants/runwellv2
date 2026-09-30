module Coding
  class SyncJob < ::ApplicationJob
    queue_as :default

    def perform
      return unless Runwell::Plugins.enabled?(:coding) && Connection.current&.connected?

      Sync.new.run!
    end
  end
end
