# Something came into Intake and the schedule says who hears it now (IntakeShift.deliver): those
# people, less anyone a plugin keeps from hearing about this client (Notice, kind "request"). Told,
# it stops waiting for a window, whoever that left out.
class Notifier::IntakeNotifier < Notifier
  alias task source

  def initialize(task, people)
    super(task)
    @people = people
  end

  def notify
    task.update_columns(intake_notified_at: Time.current)
    super
  end

  private
    def recipients = Notice.people("request", client: task.client, record: task, usual: @people)
    def creator = task.contact || task.created_by
end
