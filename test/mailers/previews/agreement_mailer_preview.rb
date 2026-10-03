# Preview at http://localhost:3000/rails/mailers/agreement_mailer (seeded data, bin/rails db:seed:replant).
class AgreementMailerPreview < ActionMailer::Preview
  def sent = AgreementMailer.with(link: ApprovalLink.take).sent
end
