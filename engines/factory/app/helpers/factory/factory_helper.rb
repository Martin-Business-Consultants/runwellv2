module Factory
  module FactoryHelper
    TONES = { "running" => "progress", "queued" => "waiting", "review" => "waiting", "blocked" => "negative",
              "failed" => "negative", "abandoned" => "negative", "succeeded" => "positive", "done" => "positive",
              "cancelled" => "neutral" }.freeze

    LABELS = { "review" => "Waiting for review" }.freeze

    # An item's state or a run's status as Fizzy's status tag, tinted by what it means.
    def factory_status_tag(state)
      tag.span LABELS.fetch(state, state.humanize), class: "status-tag status-tag--#{TONES.fetch(state, "neutral")} border-radius pad-inline-half txt-x-small txt-uppercase font-weight-bold txt-nowrap"
    end

    def factory_run_details(run)
      [ run.runner, "attempt #{run.attempt}", "#{time_ago_in_words(run.started_at)} ago",
        (distance_of_time_in_words(run.duration) if run.finished?), (money(run.cost_cents) if run.cost_cents.positive?) ].compact.join(" · ")
    end
  end
end
