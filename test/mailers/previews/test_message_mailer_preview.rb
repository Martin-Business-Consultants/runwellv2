# Preview at http://localhost:3000/rails/mailers/test_message_mailer (seeded data, bin/rails db:seed:replant).
class TestMessageMailerPreview < ActionMailer::Preview
  def check = TestMessageMailer.check(to: "you@example.org")
end
