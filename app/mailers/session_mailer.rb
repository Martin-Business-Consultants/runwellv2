# A sign-in link for someone who signs in by link (Sessions::LinksController).
class SessionMailer < ApplicationMailer
  def link
    @user = params[:user]
    @url = staff_session_link_url(@user.generate_token_for(:link_sign_in))
    mail to: @user.email_address, subject: "Your sign-in link"
  end
end
