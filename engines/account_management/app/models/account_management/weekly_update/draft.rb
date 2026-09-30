module AccountManagement
  # The first draft of a lead's weekly update, from the records: per client they lead, the week's
  # meetings, work finished, commitments kept and missed, what's due next week and accounts that
  # need attention. The lead then writes what the records can't: blockers, risks and how the
  # client feels.
  class WeeklyUpdate::Draft
    include ActionView::Helpers::TagHelper, ActionView::Helpers::OutputSafetyHelper

    def initialize(user, week_of)
      @user, @week = user, week_of.all_week(:monday)
    end

    def to_html
      clients = Lead.clients_for(@user).ordered.to_a
      return tag.p("You don’t lead any clients yet.") if clients.empty?

      safe_join(clients.map { section_for(it) })
    end

    private
      def section_for(client)
        meetings = Meeting.live.where(client: client, starts_at: @week.first.beginning_of_day..@week.last.end_of_day).order(:starts_at)
        finished = ::Todo.joins(:engagement).where(engagements: { client_id: client.id }, completed_at: @week.first.beginning_of_day..@week.last.end_of_day)
        resolved = client.commitments.where(resolved_at: @week.first.beginning_of_day..@week.last.end_of_day)
        overdue = client.commitments.overdue.ordered
        next_week = client.commitments.open.where(due_on: (@week.last + 1)..(@week.last + 7)).ordered
        accesses = client.account_accesses.ordered.reject(&:in_order?)

        safe_join([
          tag.h3(client.name),
          lines("Status", [ "On track / at risk / off track: …" ]),
          lines("Meetings", meetings.map { "#{it.title} (#{it.when_label}): #{paper_state(it)}" }),
          lines("Shipped", finished.map(&:title)),
          lines("Commitments resolved", resolved.map { "#{it.description}: #{it.resolution}" }),
          lines("Overdue", overdue.map { "#{it.description} (#{it.owner_name}, due #{it.due_on.to_fs(:long)})" }),
          lines("Next week", next_week.map { "#{it.description} (#{it.owner_name}, #{it.due_on.to_fs(:long)})" }),
          lines("Accounts needing attention", accesses.map { "#{it.platform_label} #{it.name}: #{it.problems.first}" }),
          lines("Blockers and risks", [ "…" ])
        ].compact)
      end

      def lines(heading, items)
        return if items.empty?

        tag.p(tag.strong(heading)) + tag.ul(safe_join(items.map { tag.li(it) }))
      end

      def paper_state(meeting)
        [ meeting.agenda_sent? ? "agenda sent" : "no agenda", meeting.recap_sent? ? "recap sent" : "no recap yet" ].join(", ")
      end
  end
end
