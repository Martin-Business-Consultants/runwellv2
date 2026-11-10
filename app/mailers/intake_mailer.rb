# A digest of what's waiting in Intake, for someone on the schedule who takes it that way
# (IntakeShift#send_digest): each one's title, who it came from and when, and a link to Intake.
class IntakeMailer < ApplicationMailer
  helper :tasks

  def digest(shift, task_ids)
    @shift = shift
    @tasks = Task.intake.where(id: task_ids).includes(:contact, :client, :work, :created_by).order(:intake_at).to_a
    return if @tasks.empty?

    mail to: shift.user.email_address,
         subject: "#{@tasks.size} waiting in Intake"
  end
end
