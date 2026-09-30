module Qa
  # A defect, written so whoever fixes it never has to ask: where (the URL), how to get there
  # (the steps, with screenshots pasted in), what should happen and what did, and on what
  # browser or device. Found live means a client's customer could have seen it: an escape.
  #
  # Its state is derived: open, then fixed (by whoever fixed it, with the root cause), then
  # verified (by a person, or by the next passing test of its check). Reopening clears both.
  class Issue < ::ApplicationRecord
    include ::Eventful

    ROOT_CAUSES = {
      "copy" => "Wrong or outdated copy",
      "config" => "Configuration (recipients, keys, settings)",
      "code" => "A bug in the code",
      "integration" => "Integration or third party",
      "source" => "The source of truth was wrong",
      "process" => "Skipped a step (not tested, not proofed)",
      "unknown" => "Not found"
    }.freeze
    RECORD_TYPES = %w[Client Engagement Todo].freeze

    belongs_to :client, class_name: "::Client"
    belongs_to :engagement, class_name: "::Engagement", optional: true
    belongs_to :todo, class_name: "::Todo", optional: true
    belongs_to :check, optional: true
    belongs_to :expectation, optional: true
    belongs_to :run, optional: true
    belongs_to :opened_by, class_name: "::User", optional: true
    belongs_to :assignee, class_name: "::User", optional: true
    belongs_to :fixed_by, class_name: "::User", optional: true
    belongs_to :verified_by, class_name: "::User", optional: true
    belongs_to :verified_by_run, class_name: "Qa::Run", optional: true

    scope :open, -> { where(fixed_at: nil) }
    scope :fixed, -> { where.not(fixed_at: nil).where(verified_at: nil) }
    scope :unverified, -> { where(verified_at: nil) }
    scope :verified, -> { where.not(verified_at: nil) }
    scope :live, -> { where(found_live: true) }
    scope :recent, -> { order(id: :desc) }

    validates :title, presence: true
    validates :expected, presence: { message: "can’t be blank: say what should happen" }, unless: :run
    validates :actual, presence: { message: "can’t be blank: say what happened instead" }, unless: :run
    validates :steps, presence: { message: "can’t be blank: say where and how, so it can be seen again" }, unless: :run
    validates :url, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_blank: true
    validates :root_cause, inclusion: { in: ROOT_CAUSES.keys }, allow_nil: true
    validate :context_belongs_to_client

    before_validation :fill_in_context, on: :create
    before_validation :clear_empty_text
    after_create_commit { record_event!("qa.issue_opened", payload: { live: found_live }) }

    def self.for(record)
      case record
      when ::Client then where(client: record)
      when ::Engagement then where(engagement: record)
      when ::Todo then where(todo: record)
      else none
      end
    end

    # A failed result, as an issue on its check.
    def self.open_from!(run, result)
      check = run.check
      create!(client: check.client, engagement: check.engagement, check: check, expectation: result.expectation, run: run,
        title: "#{check.name}: #{result.label}", url: check.url, expected: result.expected.presence || result.label,
        actual: result.actual, found_live: check.live, opened_by: run.user, assignee: check.owner, source: run.source,
        steps: "Found by a test (#{run.tester_label}).#{" #{run.notes}" if run.notes.present?}")
    end

    # The client, engagement or todo it's about, with what's above it.
    def about=(record)
      self.todo = record if record.is_a?(::Todo)
      self.engagement = record.is_a?(::Todo) ? record.engagement : (record if record.is_a?(::Engagement))
      self.client = record.is_a?(::Client) ? record : engagement&.client
    end

    def state
      if verified_at then "verified"
      elsif fixed_at then "fixed"
      else "open"
      end
    end

    def open? = state == "open"
    def fixed? = state == "fixed"
    def verified? = state == "verified"

    def fix!(by:, root_cause:, note: nil)
      update!(fixed_at: Time.current, fixed_by: by, root_cause: root_cause.presence || (raise ArgumentError, "a root cause is needed"), fix_note: note.presence)
      record_event!("qa.issue_fixed", payload: { root_cause: root_cause_label })
      check&.request_retest!
    end

    # By a person, or by a passing run of its check.
    def verify!(by: nil, run: nil)
      update!(verified_at: Time.current, verified_by: by || run&.user, verified_by_run: run, fixed_at: fixed_at || Time.current)
      record_event!("qa.issue_verified", payload: { by: run ? run.tester_label : by&.display_name })
    end

    def reopen!(note: nil)
      update!(fixed_at: nil, fixed_by: nil, verified_at: nil, verified_by: nil, verified_by_run: nil)
      record_event!("qa.issue_reopened", payload: { note: note.presence })
    end

    def root_cause_label = ROOT_CAUSES[root_cause]
    def label = title
    def search_title = title

    # Hours from opened to fixed, while it's open counted to now.
    def hours_to_fix = (((fixed_at || Time.current) - created_at) / 1.hour).round(1)

    def fillable_by?(user) = user.can?(:manage_qa) || user == assignee || user == opened_by

    private
      def fill_in_context
        case todo
        when ::Todo
          self.engagement ||= todo.engagement
        end
        self.client ||= engagement&.client || check&.client
      end

      # An editor left empty still sends "<p></p>"; that isn't an answer.
      def clear_empty_text
        %i[steps expected actual fix_note].each do |field|
          html = self[field].to_s
          self[field] = nil if !html.include?("<action-text-attachment") && ::ActionText::Content.new(html).to_plain_text.strip.empty?
        end
      end

      def context_belongs_to_client
        errors.add(:engagement, "must be one of the client’s") if engagement && client && engagement.client_id != client_id
        errors.add(:check, "must be one of the client’s") if check && client && check.client_id != client_id
      end
  end
end
