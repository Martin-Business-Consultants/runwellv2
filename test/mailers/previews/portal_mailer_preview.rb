# Preview at http://localhost:3000/rails/mailers/portal_mailer (seeded data, bin/rails db:seed:replant).
class PortalMailerPreview < ActionMailer::Preview
  def magic_link = PortalMailer.with(contact: contact).magic_link
  def invitation = PortalMailer.with(contact: contact).invitation

  def reply
    note = Note.client_visible.where(subject_type: "Task").take || Note.where(subject_type: "Task").take
    PortalMailer.with(note: note, contact: contact).reply
  end

  def done = PortalMailer.with(task: Task.client_visible.where(status: "done").take, contact: contact).done

  private
    def contact = Contact.with_portal_access.where.not(email: [ nil, "" ]).take
end
