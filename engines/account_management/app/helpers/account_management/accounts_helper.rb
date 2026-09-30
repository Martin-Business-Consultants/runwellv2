module AccountManagement
  module AccountsHelper
    ACCOUNT_TONES = { "planned" => "neutral", "agenda_due" => "waiting", "recap_due" => "waiting", "done" => "positive", "cancelled" => "neutral",
      "late" => "negative", "on_time" => "positive", "in_order" => "positive", "attention" => "negative", "draft" => "waiting", "sent" => "positive" }.freeze
    ACCOUNT_LABELS = { "agenda_due" => "Agenda due", "recap_due" => "Recap due", "on_time" => "On time", "in_order" => "In order",
      "attention" => "Needs attention" }.freeze

    def account_status_tag(state)
      tag.span ACCOUNT_LABELS.fetch(state, state.humanize), class: "status-tag status-tag--#{ACCOUNT_TONES.fetch(state, "neutral")} border-radius pad-inline-half txt-x-small txt-uppercase font-weight-bold txt-nowrap"
    end

    # A meeting's state, or "late" once the paper it's waiting on has missed its deadline.
    def account_meeting_tag(meeting)
      late = (meeting.state == "agenda_due" && meeting.agenda_late?) || (meeting.state == "recap_due" && meeting.recap_late?)
      account_status_tag late ? "late" : meeting.state
    end

    # When it starts in our zone, and in the client's when theirs differs: "Oct 2, 2:00 PM · 11:00 AM PDT for them".
    def account_meeting_time(meeting, format: :long)
      ours = l(meeting.starts_at.in_time_zone, format: format)
      return ours unless meeting.client.own_time_zone?

      "#{ours} · #{l meeting.starts_at.in_time_zone(meeting.client.zone), format: "%-l:%M %p %Z"} for them"
    end

    def account_people_options = ::User.active.people.ordered.map { [ it.display_name, it.id ] }

    def account_percent(value) = value.nil? ? "—" : "#{value}%"

    # "sent Sep 27, 2:10 PM · on time", or when it's due.
    def account_paper_line(meeting, paper)
      sent_at = meeting.public_send(:"#{paper}_sent_at")
      due_at = meeting.public_send(:"#{paper}_due_at")
      if sent_at
        "Sent #{l sent_at, format: :short}, #{meeting.public_send(:"#{paper}_on_time") ? "on time" : "late"}"
      elsif meeting.cancelled?
        "Not sent"
      else
        "#{Time.current > due_at ? "Was due" : "Due"} by #{l due_at, format: :short}"
      end
    end
  end
end
