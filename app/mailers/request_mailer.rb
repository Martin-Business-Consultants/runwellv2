# Tells a contact who emailed a request that it came in. Replying adds to the same request: the
# reply goes to its plus address (requests+r42-…@) and threads on its Message-ID (RequestsMailbox).
class RequestMailer < ApplicationMailer
  def received
    @request = params[:request]
    setting = Setting.current
    domain = setting.requests_email.split("@").last

    headers["Auto-Submitted"] = "auto-replied"
    headers["Message-ID"] = "<request-#{@request.id}-#{@request.reply_token}@#{domain}>"
    if params[:in_reply_to].present?
      headers["In-Reply-To"] = "<#{params[:in_reply_to]}>"
      headers["References"] = "<#{params[:in_reply_to]}>"
    end

    mail to: email_address_with_name(@request.sender_email, @request.requester_name), reply_to: setting.requests_reply_address(@request),
         subject: "Re: #{@request.subject}"
  end
end
