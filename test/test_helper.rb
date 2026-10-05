ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    setup { Current.source = "test" }

    # Send and approve a fixture draft so a test starts from agreed terms.
    def approve!(engagement, actor: users(:ted), contact: nil)
      version = engagement.draft_version
      version.send!(actor: actor)
      contact ||= engagement.client.approvers.first
      version.decide!(decision: "approved", method: "recorded", contact: contact, evidence: "email on file", recorded_by: actor)
      version
    end
  end
end
