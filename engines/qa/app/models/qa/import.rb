module Qa
  # A client's checks from a file (see examples/acme_storage.yml), so a site's source of
  # truth can be written down once, reviewed like code, and loaded again whenever it changes.
  # Checks match by name and expectations by key: new ones are added, changed values are
  # updated (and recorded on the client's history), and nothing is removed.
  class Import
    Summary = Struct.new(:client, :checks_added, :checks_updated, :facts_added, :facts_changed, keyword_init: true) do
      def to_s = "#{client.name}: #{checks_added} checks added, #{checks_updated} updated; #{facts_added} facts added, #{facts_changed} changed"
    end

    def initialize(data)
      @data = data.deep_stringify_keys
    end

    def call
      summary = Summary.new(checks_added: 0, checks_updated: 0, facts_added: 0, facts_changed: 0)
      ::ApplicationRecord.transaction do
        client = ::Client.find_or_create_by!(name: @data.fetch("client"))
        summary.client = client
        Array(@data["checks"]).each { import_check(client, it, summary) }
      end
      summary
    end

    private
      def import_check(client, attributes, summary)
        check = Check.active.find_or_initialize_by(client: client, name: attributes.fetch("name"))
        summary[check.new_record? ? :checks_added : :checks_updated] += 1
        check.assign_attributes(attributes.slice("kind", "url", "live", "every_days", "instructions").compact)
        check.engagement = ::Engagement.find_by_ref!(attributes["engagement"]) if attributes["engagement"]
        check.owner = ::User.active.people.find_by!(email_address: attributes["owner"]) if attributes["owner"]
        check.save!

        Array(attributes["expectations"]).each_with_index do |fact, index|
          fact = fact.stringify_keys
          expectation = check.expectations.find_or_initialize_by(key: fact["key"].presence || Expectation.key_for(fact.fetch("label")))
          summary[:facts_added] += 1 if expectation.new_record?
          expected = fact["expected"].is_a?(Array) ? fact["expected"].join(", ") : fact["expected"]&.to_s
          expectation.assign_attributes(label: fact.fetch("label"), expected: expected, match: fact["match"] || "is",
            expires_on: fact["expires_on"], note: fact["note"], position: index)
          summary[:facts_changed] += 1 if expectation.persisted? && expectation.will_save_change_to_expected?
          expectation.save!
        end
      end
  end
end
