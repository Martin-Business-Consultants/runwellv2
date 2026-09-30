class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    mail subject: "#{invitation.invited_by.display_name} invited you to Runwell", to: invitation.email_address
  end
end
