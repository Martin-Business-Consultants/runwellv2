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

    # The Inertia page a controller rendered, from the data script in the layout.
    def inertia_page
      json = Nokogiri::HTML(response.body).at_css("script[data-page]")&.text || response.body[/data-page="([^"]*)"/, 1]&.then { |s| CGI.unescapeHTML(s) }
      ::JSON.parse(json)
    end

    def inertia_props = inertia_page["props"]
    def inertia_component = inertia_page["component"]
  end
end
