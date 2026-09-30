module Qa
  # One agreed fact on a check, the source of truth for it: "From address is
  # hello@acme-storage.example", "the page never shows (720) 555-0199", "the promo line is … until 9/30".
  # With no expected value it is a step to tick off ("every link clicked"). The key is fixed at
  # creation, so a site's own report can name it.
  #
  # Changing an expected value is recorded on the client's history, and every earlier pass
  # stops counting: what was checked is no longer what was agreed.
  class Expectation < ::ApplicationRecord
    belongs_to :check, inverse_of: :expectations
    belongs_to :approved_by, class_name: "::User", optional: true
    has_many :results, dependent: :nullify

    validates :label, presence: true
    validates :key, presence: true, uniqueness: { scope: :check_id }, format: { with: /\A[a-z0-9_]+\z/ }
    validates :match, inclusion: { in: Matcher::MATCHES.keys }
    validates :expected, presence: { message: "is needed to check that something appears, or never does" }, if: -> { match.in?(Matcher::PAGE_MATCHES) }

    before_validation(on: :create) { self.key = self.class.key_for(label) if key.blank? }
    before_validation { self.expected = expected.to_s.strip.presence }
    before_save :approve, if: -> { new_record? || will_save_change_to_expected? || will_save_change_to_match? }
    after_update :record_change, if: -> { saved_change_to_expected? || saved_change_to_match? }

    # "Thank-you price" → "thank_you_price".
    def self.key_for(label) = label.to_s.delete("'’").parameterize(separator: "_").tr("-", "_").squeeze("_").first(60).delete_suffix("_").presence

    def value? = expected.present?
    def step? = !value?
    def fetchable? = value? && match.in?(Matcher::PAGE_MATCHES)
    def expired? = expires_on.present? && expires_on < Date.current
    def expiring?(within: 14.days) = expires_on.present? && expires_on <= Date.current + within

    def match_label = Matcher::MATCHES.fetch(match)

    # The whole rule in words, e.g. "From address is exactly hello@acme-storage.example".
    def rule = value? ? "#{label} #{match_label} “#{expected}”" : label

    # A person's or a report's answer, as { passed:, actual: }. A step or an unchanged value
    # passes on the tester's word; anything they typed is compared. given: the answer is the
    # value itself (a site's report), so an empty one means it sent nothing, and fails.
    def judge(actual: nil, verdict: nil, given: false)
      actual = actual.presence
      compared = value? && (actual || given)
      return unless compared || verdict.in?(%w[pass fail])

      # "Wrong" always wins; "right" still has to match what was typed.
      passed = verdict != "fail" && (!compared || Matcher.match?(match, expected, actual.to_s))
      { passed: passed, actual: actual || ("(nothing)" if given) || (expected if passed && value?) }
    end

    private
      def approve
        self.approved_by = Current.user
        self.approved_at = Time.current
      end

      def record_change
        check.client.record_event!("qa.source_of_truth_changed",
          payload: { check: check.name, fact: label, from: expected_before_last_save.to_s.truncate(120), to: expected.to_s.truncate(120) })
        check.request_retest!
      end
  end
end
