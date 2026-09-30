module Qa
  # One thing we're accountable for on a client: the quote email to the customer, the lead
  # alert to the office, the thank-you page, the webhook into the CRM. Its expectations are the
  # source of truth (the From address, the recipients, the phone number, the price), and its
  # runs are the proof they were checked.
  #
  # Its state is derived from the latest result for each expectation: failing when any of them
  # last failed, due when any has never been tested or not within every_days (or since a
  # deploy asked for a retest), otherwise passing.
  class Check < ::ApplicationRecord
    KINDS = %w[email page webhook form other].freeze
    STATES = %w[failing due passing].freeze

    belongs_to :client, class_name: "::Client"
    belongs_to :engagement, class_name: "::Engagement", optional: true
    belongs_to :owner, class_name: "::User", optional: true
    belongs_to :created_by, class_name: "::User", optional: true
    has_many :expectations, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :check
    has_many :runs, dependent: :destroy
    has_many :issues, dependent: :nullify
    has_many :gates, dependent: :destroy

    has_secure_token :report_token

    scope :active, -> { where(archived_at: nil) }
    scope :ordered, -> { order(:name) }
    scope :live, -> { where(live: true) }

    validates :name, presence: true
    validates :kind, inclusion: { in: KINDS }
    validates :every_days, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }
    validates :url, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_blank: true
    validate :engagement_belongs_to_client

    before_validation { self.url = url.presence&.strip }

    # The usual list for each kind ([label, match]), so a new check starts complete instead of
    # from memory. A blank expected value is a step to tick off; fill one in and it's a value to
    # compare.
    TEMPLATES = {
      "email" => [
        [ "Subject", "is" ], [ "From name", "is" ], [ "From address", "is" ], [ "Reply-to", "is" ],
        [ "To", "list" ], [ "CC", "list" ],
        [ "Body matches the approved copy", "is" ], [ "Merge tags filled in from a test record", "is" ],
        [ "Prices, dates and offers match the source of truth", "is" ], [ "Every link and button clicked, UTMs right", "is" ],
        [ "Footer, address and unsubscribe present", "is" ], [ "Reads well on mobile, Gmail, Outlook and Apple Mail", "is" ]
      ],
      "page" => [
        [ "Phone number", "includes" ], [ "Price", "includes" ], [ "Headline", "includes" ],
        [ "Form fields, validation and required logic", "is" ], [ "Thank-you page shows after submitting", "is" ],
        [ "Layout on mobile", "is" ], [ "Analytics and pixels fire", "is" ]
      ],
      "webhook" => [
        [ "Endpoint URL", "is" ], [ "Keys sent", "list" ],
        [ "A live test lead arrives with every field filled", "is" ], [ "Failures alert someone the same day", "is" ]
      ],
      "form" => [
        [ "Required fields enforced", "is" ], [ "Thank-you page and its pricing", "is" ],
        [ "Customer email arrives", "is" ], [ "Office email arrives", "is" ], [ "CRM record created", "is" ]
      ],
      "other" => []
    }.freeze

    def self.for(record)
      case record
      when ::Client then where(client: record)
      when ::Engagement then where(engagement: record)
      else none
      end
    end

    def apply_template!
      TEMPLATES.fetch(kind, []).each_with_index do |(label, match), index|
        expectations.create!(label: label, match: match, position: index)
      end
    end

    def archived? = archived_at.present?

    # The latest result per expectation, as { expectation_id => result }.
    def latest_results
      @latest_results ||= begin
        ids = Result.joins(:run).where(qa_runs: { check_id: id }).where.not(expectation_id: nil).group(:expectation_id).maximum(:id).values
        Result.where(id: ids).includes(run: :user).index_by(&:expectation_id)
      end
    end

    def reload(*)
      @latest_results = nil
      super
    end

    def state
      return "due" if expectations.empty?
      return "failing" if expectations.any? { latest_results[it.id]&.passed == false }

      stale?(expectations) ? "due" : "passing"
    end

    # { "passed" => 9, "failed" => 1, "untested" => 3 }, from the latest result per expectation.
    def tally
      expectations.map { |it| latest_results[it.id].then { |result| result.nil? ? "untested" : (result.passed ? "passed" : "failed") } }.tally
    end

    # When the next test is due: now when it's due already, else when the oldest pass runs out.
    def next_test_at
      return Time.current if due? || failing?

      expectations.map { latest_results[it.id].created_at }.min + every_days.days
    end

    def failing? = state == "failing"
    def due? = state == "due"

    # When an expectation's latest pass stops counting: every_days after it, or at a retest.
    def stale?(list)
      list.any? do |expectation|
        result = latest_results[expectation.id]
        result.nil? || result.created_at < every_days.days.ago || (retest_after && result.created_at < retest_after)
      end
    end

    def last_run = runs.order(:id).last

    # Expectations the nightly fetch can answer from the page itself.
    def fetchable_expectations = url.present? ? expectations.select(&:fetchable?) : []
    def fetchable? = fetchable_expectations.any?

    # A deploy or a changed source of truth: every pass before now needs doing again.
    def request_retest!(at: Time.current) = update_columns(retest_after: at, updated_at: Time.current)

    def label = "#{name} · #{client.name}"
    def search_title = name

    def archive!
      update!(archived_at: Time.current)
    end

    private
      def engagement_belongs_to_client
        errors.add(:engagement, "must be one of the client’s") if engagement && engagement.client_id != client_id
      end
  end
end
