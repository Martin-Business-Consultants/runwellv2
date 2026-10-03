# Preview at http://localhost:3000/rails/mailers/portal_mailer (seeded data, bin/rails db:seed:replant).
class PortalMailerPreview < ActionMailer::Preview
  def magic_link = PortalMailer.with(contact: Contact.where.not(email: [ nil, "" ]).take).magic_link
end
