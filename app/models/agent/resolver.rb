# What a person calls a record, turned into the record: "Bloom", "priya", "the holiday hours job",
# "WO-12". A tool's ids (path ids, client_id, owner_id… and "Type:name" records) may be names;
# Agent::Dispatch resolves them here before the request runs. One match is used; several answer
# "ambiguous" with the candidates to choose from; none answers "not_found". The resolve tool
# offers the same lookup directly.
module Agent
  module Resolver
    class Ambiguous < StandardError
      attr_reader :candidates

      def initialize(type, text, candidates)
        @candidates = candidates
        super("More than one #{type.underscore.humanize(capitalize: false)} matches “#{text}”.")
      end
    end

    class Missing < StandardError
      def initialize(type, text) = super("No #{type.underscore.humanize(capitalize: false)} matches “#{text}”.")
    end

    # The name columns each kind of record is called by.
    FIELDS = { "Client" => %w[name], "Contact" => %w[name email], "User" => %w[name email_address],
               "Engagement" => %w[title], "Todo" => %w[title], "Request" => %w[subject],
               "Commitment" => %w[description], "ScopeItem" => %w[description] }.freeze

    # Parameters that hold an id, and the kind of record they name.
    PARAMS = { "client_id" => "Client", "contact_id" => "Contact", "engagement_id" => "Engagement", "owner_id" => "User",
               "user_id" => "User", "todo_id" => "Todo", "scope_item_id" => "ScopeItem", "request_id" => "Request" }.freeze

    REF = /\A[A-Za-z]+-\d+\z/

    class << self
      def types = FIELDS.keys
      def id?(value) = value.is_a?(Integer) || value.to_s.match?(/\A\d+\z/)

      # Records of the type that text names, best first: an engagement's ref, then names equal to
      # it (any case), then starting with it, then containing it, then full-text search. For a
      # client's agent (client:), only that client's engagements and shared work, nothing else.
      def candidates(type, text, limit: 8, client: nil)
        text = text.to_s.strip
        return [] if text.blank? || !FIELDS.key?(type)

        scope = client ? within(client, type) : base(type)
        return [] if scope.nil?
        if type == "Engagement" && text.match?(REF)
          return Array(scope.find_by(ref: text.upcase))
        end

        lowered = text.downcase
        like = ActiveRecord::Base.sanitize_sql_like(lowered)
        [ [ "= :value", lowered ], [ "LIKE :value ESCAPE '\\'", "#{like}%" ], [ "LIKE :value ESCAPE '\\'", "%#{like}%" ] ].each do |operator, value|
          found = scope.where(FIELDS[type].map { "lower(#{it}) #{operator}" }.join(" OR "), value: value).limit(limit).to_a
          return found if found.any?
        end

        model = type.constantize
        Search.new(text).results.select { it.is_a?(model) && (client.nil? || scope.exists?(it.id)) }.first(limit)
      end

      # The one record text names, or Ambiguous / Missing.
      def resolve(type, text, client: nil)
        found = candidates(type, text, client: client)
        raise Missing.new(type, text) if found.empty?
        raise Ambiguous.new(type, text, found) if found.size > 1

        found.first
      end

      # An id as given, or the id of the record a name stands for.
      def id_for(type, value, client: nil) = id?(value) ? value : resolve(type, value, client: client).id

      def describe(record)
        client = record.is_a?(Client) ? nil : (record.try(:client) || record.try(:engagement)&.client)
        { "type" => record.class.name, "id" => record.id, "record" => "#{record.class.name}:#{record.id}", "ref" => record.try(:ref),
          "name" => label(record), "client" => client&.name }.compact
      end

      private
        def within(client, type)
          case type
          when "Engagement" then client.engagements
          when "Todo" then Todo.client_visible.joins(:engagement).where(engagements: { client_id: client.id })
          when "Request" then client.requests
          end
        end

        def base(type)
          case type
          when "User" then User.active.people
          when "Contact" then Contact.active
          else type.constantize.all
          end
        end

        def label(record)
          case record
          when User then record.display_name
          when Engagement then "#{record.ref} #{record.title}"
          else record.try(:name) || record.try(:title) || record.try(:subject) || record.try(:description).to_s.truncate(80)
          end
        end
    end
  end
end
