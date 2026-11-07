# Preview at http://localhost:3000/rails/mailers/request_mailer (seeded data, bin/rails db:seed:replant).
class RequestMailerPreview < ActionMailer::Preview
  def received = RequestMailer.with(task: Task.where.not(contact_id: nil).take).received
end
