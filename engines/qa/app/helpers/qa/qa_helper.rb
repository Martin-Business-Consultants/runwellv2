module Qa
  module QaHelper
    QA_TONES = { "failing" => "negative", "due" => "waiting", "passing" => "positive", "passed" => "positive", "failed" => "negative",
      "open" => "negative", "fixed" => "waiting", "verified" => "positive" }.freeze
    QA_LABELS = { "due" => "Due for a test" }.freeze

    def qa_status_tag(state)
      tag.span QA_LABELS.fetch(state, state.humanize), class: "status-tag status-tag--#{QA_TONES.fetch(state, "neutral")} border-radius pad-inline-half txt-x-small txt-uppercase font-weight-bold txt-nowrap"
    end

    # "3 days ago by Priya", or "never".
    def qa_tested(result)
      return "never tested" unless result

      "#{time_ago_in_words(result.created_at)} ago · #{result.run.tester_label}"
    end

    # Where the check's site posts its own test. Not the route helper's name, which it uses.
    def qa_report_address(check) = qa_report_url(check.report_token)

    def qa_owner_options = ::User.active.people.ordered.map { [ it.display_name, it.id ] }

    def qa_percent(value) = value.nil? ? "—" : "#{value}%"

    def qa_hours(hours)
      return "—" if hours.nil?

      if hours < 1 then "#{(hours * 60).round}m"
      elsif hours < 48 then "#{hours.round}h"
      else "#{(hours / 24).round(1)}d"
      end
    end
  end
end
