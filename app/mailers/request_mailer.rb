# Tells a contact who emailed a request that it came in, threaded under their message. It isn't
# something to reply to: anything new they send is a request of its own.
class RequestMailer < ApplicationMailer
  def received
    @request = params[:task]
    headers["Auto-Submitted"] = "auto-replied"
    if params[:in_reply_to].present?
      headers["In-Reply-To"] = "<#{params[:in_reply_to]}>"
      headers["References"] = "<#{params[:in_reply_to]}>"
    end

    mail to: email_address_with_name(@request.sender_email, @request.requester_name),
         subject: "Re: #{@request.title}"
  end
end
