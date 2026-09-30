module Qa
  # The numbers QA is held to, over the last `days`: how much was tested, how many defects were
  # found and how many of them were live (escapes), how fast they were fixed, and what caused
  # them.
  class Stats
    attr_reader :days

    def initialize(days: 30)
      @days = days
      @checks = Check.active.includes(:expectations).to_a
      @since = days.days.ago
    end

    def runs = @runs ||= Run.where(created_at: @since..)
    def tests = runs.count
    def pass_rate = tests.zero? ? nil : (runs.where(status: "passed").count * 100.0 / tests).round

    def issues = @issues ||= Issue.where(created_at: @since..)
    def opened = issues.count
    def escapes = issues.live.count
    def caught = opened - escapes
    def escape_rate = opened.zero? ? nil : (escapes * 100.0 / opened).round

    def median_hours_to_fix
      hours = Issue.where(fixed_at: @since..).map(&:hours_to_fix).sort
      hours.empty? ? nil : hours[hours.size / 2]
    end

    def open_now = Issue.open.count
    def awaiting_verification = Issue.fixed.count
    def oldest_open = Issue.open.order(:created_at).first

    def states = @states ||= @checks.map(&:state).tally
    def failing = states.fetch("failing", 0)
    def due = states.fetch("due", 0)
    def passing = states.fetch("passing", 0)

    def root_causes = Issue.where(fixed_at: @since..).where.not(root_cause: nil).group(:root_cause).count.sort_by { -it.last }
  end
end
