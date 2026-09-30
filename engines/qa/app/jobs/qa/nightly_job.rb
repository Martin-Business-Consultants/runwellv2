# Fetches every live check's page each night and answers what the page itself can:
# the phone number is there, the price is right, the other market's number never shows.
module Qa
  class NightlyJob < ApplicationJob
    def perform
      Current.source = "qa"
      Check.active.live.where.not(url: nil).includes(:expectations).find_each do |check|
        PageFetch.new(check).call if check.fetchable?
      rescue StandardError => e
        Rails.logger.error("[Qa::NightlyJob] #{check.name}: #{e.class}: #{e.message}")
      end
    end
  end
end
