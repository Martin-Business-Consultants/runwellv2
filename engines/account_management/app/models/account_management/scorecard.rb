module AccountManagement
  # How a lead did against the playbook over the last N days, from what they actually did:
  # agendas sent a day ahead, recaps sent within a day, their commitments kept by the date
  # promised, and weekly updates sent by Friday. Each measure keeps the records that missed, so
  # a conversation about the numbers starts from facts. Only what's settled counts: a meeting
  # whose agenda can still go out on time, or a commitment not yet due, is left out.
  class Scorecard
    Measure = Struct.new(:key, :label, :target, :kept, :misses, keyword_init: true) do
      def total = kept + misses.size
      def percent = total.zero? ? nil : (kept * 100.0 / total).round
      def met? = percent.nil? || percent >= target
    end

    attr_reader :user, :days

    def initialize(user, days: 30)
      @user, @days = user, days
    end

    def since = days.days.ago

    def measures = @measures ||= [ agendas, recaps, commitments, updates ]
    def met? = measures.all?(&:met?)

    def clients = @clients ||= Lead.clients_for(user).ordered.to_a
    def accesses_needing_attention = @accesses ||= Access.where(client: clients).ordered.reject(&:in_order?)
    def overdue_commitments = ::Commitment.overdue.where(owner_kind: "us", user: user).ordered.includes(:client)

    private
      def meetings = @meetings ||= Meeting.live.where(owner: user, starts_at: since..Time.current).includes(:client).to_a

      def agendas = paper(:agendas, "Agendas sent #{hours Playbook::AGENDA_AHEAD} ahead", :agenda_on_time)
      def recaps = paper(:recaps, "Recaps sent within #{hours Playbook::RECAP_WITHIN}", :recap_on_time)

      def paper(key, label, check)
        settled = meetings.reject { it.public_send(check).nil? }
        Measure.new(key: key, label: label, target: Playbook::TARGETS[key],
          kept: settled.count { it.public_send(check) }, misses: settled.reject { it.public_send(check) })
      end

      # Ours, on this person, due in the window. Done by the date is kept; done late, missed, or
      # still open past its date is a miss. Dropped (agreed not to do) doesn't count either way.
      def commitments
        due = ::Commitment.where(owner_kind: "us", user: user, due_on: since.to_date...Date.current)
          .where("resolution IS NULL OR resolution <> ?", "dropped").includes(:client).to_a
        kept = due.select { it.resolution == "done" && it.resolved_at.to_date <= it.due_on }
        Measure.new(key: :commitments, label: "Commitments kept by their date", target: Playbook::TARGETS[:commitments],
          kept: kept.size, misses: due - kept)
      end

      # Each week whose Friday deadline fell in the window, while they led a client.
      def updates
        sent = WeeklyUpdate.where(user: user).index_by(&:week_of)
        weeks = (since.to_date..Date.current).map { WeeklyUpdate.week_of(it) }.uniq
          .map { sent[it] || WeeklyUpdate.new(user: user, week_of: it) }
          .select { it.due_at.between?(since, Time.current) && Lead.where(user: user).where(created_at: ..it.due_at).exists? }
        Measure.new(key: :updates, label: "Weekly updates sent by Friday", target: Playbook::TARGETS[:updates],
          kept: weeks.count(&:on_time?), misses: weeks.reject(&:on_time?))
      end

      def hours(duration) = "#{(duration / 1.hour).round}h"
  end
end
