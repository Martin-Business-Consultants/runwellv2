# Preview at http://localhost:3000/rails/mailers/invitation_mailer (seeded data, bin/rails db:seed:replant).
class InvitationMailerPreview < ActionMailer::Preview
  def invite = InvitationMailer.invite(Invitation.take || Invitation.new(email_address: "new@example.org", role: "member", invited_by: User.people.take, sent_at: Time.current))
end
