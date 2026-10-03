# How requests' mail comes in (Settings > Email), when the server's environment doesn't say: the
# service forwarding it, with a password made for it the first time.
class Settings::Emails::InboundsController < Settings::BaseController
  agent_exempt :update, reason: "it makes the password a mail service signs in with, shown to a person in the browser"

  def update
    ingress = params.dig(:inbound, :ingress).presence_in(%w[relay postmark sendgrid])
    if ingress
      Setting.current.receive_mail_through!(ingress)
      redirect_to settings_email_path(anchor: "requests_by_email"), notice: "Requests’ mail comes in through #{helpers.inbound_ingress_name(ingress)}. Give it the address and password shown."
    else
      Setting.current.update!(inbound_ingress: nil)
      redirect_to settings_email_path(anchor: "requests_by_email"), notice: "Runwell isn’t receiving requests by email."
    end
  end
end
