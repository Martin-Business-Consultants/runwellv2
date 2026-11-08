# A client set to dormant or former takes its work with it: every open piece of work closes as
# cancelled and every open task is marked done, each saying why in its history ("Harbor Dental set
# to dormant"), and the client records client.sunset with what closed. Setting it active again
# changes only the client: reopen work and tasks by hand. However the status changes (the form,
# the status picker, the bulk bar, an agent), it runs here, in the same transaction.
module Client::Sunset
  extend ActiveSupport::Concern

  included do
    after_update :sunset_work_and_tasks, if: -> { saved_change_to_status? && status != "active" }
  end

  # What the last status change closed: { works:, tasks: }, for the notice.
  attr_reader :sunset_counts

  def sunset_reason = "#{name} set to #{status}"

  # "Closed 2 projects as cancelled and marked 9 tasks done.", or nil when nothing was open.
  def sunset_summary
    return unless sunset_counts&.values&.any?(&:positive?)

    setting = Setting.current
    works, tasks = sunset_counts.values_at(:works, :tasks)
    parts = []
    parts << "closed #{works} #{setting.term(:work, count: works).downcase} as cancelled" if works.positive?
    parts << "marked #{tasks} #{setting.term(:task, count: tasks).downcase} done" if tasks.positive?
    "#{parts.to_sentence.upcase_first}."
  end

  private
    def sunset_work_and_tasks
      reason = sunset_reason
      works = self.works.open.to_a
      works.each { it.close!(outcome: "cancelled", reason: reason) }
      tasks = self.tasks.open.to_a
      tasks.each do |task|
        task.status_reason = reason
        task.update!(status: "done")
      end
      @sunset_counts = { works: works.size, tasks: tasks.size }
      record_event!("client.sunset", payload: { status: status, reason: reason, works: works.map(&:ref), tasks: tasks.size }) if works.any? || tasks.any?
    end
end
