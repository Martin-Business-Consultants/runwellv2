# A sign-in link for someone who signs in by link (Sessions::LinksController).
class SessionMailer < ApplicationMailer
  def link
    @user = params[:user]
    @url = staff_session_link_url(@user.generate_token_for(:link_sign_in))
    mail to: @user.email_address, subject: "Your sign-in link"
  end

  # Someone on the team asked for a link without having switched link sign-in on: told how, so
  # the request isn't met with silence. Only the address's owner sees it, so the form still
  # reveals nothing about who has an account.
  def link_off
    @user = params[:user]
    @url = new_session_url
    @account_url = settings_account_url
    mail to: @user.email_address, subject: "Signing in by email isn’t on for your account"
  end
end
