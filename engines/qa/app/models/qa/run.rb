module Qa
  # One test of a check, and the proof of it: who or what tested (a person, an agent, the
  # nightly page fetch, or the site's own report), what was seen for each expectation, and a
  # link to the evidence. Never changed afterwards.
  #
  # A failed expectation opens an issue (one per expectation, not one per run, so a canary
  # failing every day doesn't bury the log), and a pass verifies any issue on it that was
  # marked fixed.
  class Run < ::ApplicationRecord
    SOURCES = { "person" => "Tested by hand", "agent" => "Tested by an agent", "page" => "Page fetched", "report" => "Reported by the site" }.freeze

    belongs_to :check
    belongs_to :user, class_name: "::User", optional: true
    has_many :results, dependent: :destroy
    has_many :issues, dependent: :nullify
    has_many :verified_issues, class_name: "Qa::Issue", foreign_key: :verified_by_run_id, dependent: :nullify, inverse_of: :verified_by_run

    scope :recent, -> { order(id: :desc) }

    validates :source, inclusion: { in: SOURCES.keys }
    validates :status, inclusion: { in: %w[passed failed] }
    validates :evidence_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be a link" }, allow_blank: true
    validate { errors.add(:base, "Test at least one thing") if results.empty? }

    before_update { raise ActiveRecord::ReadOnlyRecord, "runs are never changed" }

    # answers: { key => { actual:, verdict: "pass"|"fail" } }, { key => "what was seen" }, or for
    # a step { key => true }.
    # Keys that aren't on the check come back as unknown; expectations with no answer weren't
    # tested this time.
    def self.record(check:, answers:, source:, user: Current.user, notes: nil, evidence_url: nil, reporter: nil, http_status: nil)
      run = new(check: check, user: user, source: source, reporter: reporter, notes: notes.presence, evidence_url: evidence_url.presence, http_status: http_status)
      answers = answers.to_h.transform_keys(&:to_s)
      run.unknown_keys = answers.keys - check.expectations.map(&:key)

      check.expectations.each do |expectation|
        next unless answers.key?(expectation.key)

        answer = answers[expectation.key]
        given = !answer.is_a?(Hash)
        if given && expectation.step? && answer.to_s.in?(%w[true false pass fail])
          answer, given = { "verdict" => answer.to_s.in?(%w[true pass]) ? "pass" : "fail" }, false
        end
        answer = given ? { "actual" => answer } : answer.to_h.stringify_keys
        actual = answer["actual"].is_a?(Array) ? answer["actual"].join(", ") : answer["actual"].to_s
        judged = expectation.judge(actual: actual, verdict: answer["verdict"], given: given)
        next unless judged

        if !judged[:passed] && judged[:actual].blank?
          run.errors.add(:base, "Say what you saw for “#{expectation.label}”")
          next
        end
        run.results.build(expectation: expectation, key: expectation.key, label: expectation.label, expected: expectation.expected, **judged)
      end
      run.status = run.results.any? { !it.passed } ? "failed" : "passed"

      if run.errors.none? && run.save
        run.follow_up
      end
      run
    end

    attr_accessor :unknown_keys

    def passed? = status == "passed"
    def failed? = !passed?

    def label = "#{check.name} test"

    def tester_label
      user&.display_name || reporter.presence || SOURCES.fetch(source)
    end

    def summary
      failures = results.reject(&:passed)
      failures.any? ? "#{failures.size} of #{results.size} failed: #{failures.map(&:label).to_sentence}" : "All #{results.size} passed"
    end

    # Issues for what failed, verification for what was fixed and now passes, and a line on the
    # client's history when something broke.
    def follow_up
      results.each do |result|
        if result.passed
          check.issues.fixed.where(expectation_id: result.expectation_id).find_each { it.verify!(run: self) }
        elsif check.issues.unverified.where(expectation_id: result.expectation_id).none?
          Issue.open_from!(self, result)
        end
      end
      check.client.record_event!("qa.check_failed", payload: { check: check.name, failed: results.reject(&:passed).map(&:label).to_sentence }) if failed?
    end
  end
end
