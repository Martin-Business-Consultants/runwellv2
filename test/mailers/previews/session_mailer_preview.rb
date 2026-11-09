# Preview all emails at http://localhost:3000/rails/mailers/session_mailer
class SessionMailerPreview < ActionMailer::Preview
  def link
    SessionMailer.with(user: User.people.take).link
  end

  # Asked for a link without having switched link sign-in on.
  def link_off
    SessionMailer.with(user: User.people.take).link_off
  end
end
