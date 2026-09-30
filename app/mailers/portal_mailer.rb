class PortalMailer < ApplicationMailer
  def magic_link
    @contact = params[:contact]
    @url = portal_session_link_url(@contact.generate_token_for(:portal_login))
    mail to: @contact.email, subject: "Your sign-in link"
  end
end
