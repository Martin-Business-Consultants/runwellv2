# Preview at http://localhost:3000/rails/mailers/request_mailer (seeded data, bin/rails db:seed:replant).
class RequestMailerPreview < ActionMailer::Preview
  def received = RequestMailer.with(request: Request.where.not(sender_email: nil).take).received
end
