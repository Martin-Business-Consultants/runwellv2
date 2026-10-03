# A client's email, as a request. A reply to one of ours (by its plus address, or the thread's
# Message-ID) becomes a note on that request instead. The subject is the title, the body the
# description, cleaned of quoted mail and signatures (Request::EmailBody), and attachments become
# its documents. Automatic replies and our own mail are dropped. A known contact gets a short
# acknowledgement they can reply to.
class RequestsMailbox < ApplicationMailbox
  REPLY_ADDRESS = /\+r(\d+)-(\h{12})@/i
  REPLY_MESSAGE_ID = /request-(\d+)-(\h{12})@/i

  def process
    return if automatic? || from_ourselves?

    Current.set(source: "email") do
      if (request = replied_to)
        add_reply(request)
      else
        receive_request
      end
    end
  end

  private
    def sender_email = mail.from_address&.address.to_s.downcase
    def sender_name = mail.from_address&.display_name.presence || mail[:from]&.display_names&.first.presence
    def body = @body ||= Request::EmailBody.new(mail)

    def receive_request
      request = Request.create!(subject: title, body: body.to_html, sender_name: sender_name, sender_email: sender_email,
                                source: "email", received_at: mail.date || Time.current)
      attach_files(request)
      request.record_event!("request.received", actor: nil, source: "email", actor_label: request.requester_name)

      if request.contact && Setting.current.requests_email.present?
        RequestMailer.with(request: request, in_reply_to: mail.message_id).received.deliver_later
      end
    end

    def add_reply(request)
      files = attach_files(request)
      text = body.to_html.presence || "<p>Sent #{files.size == 1 ? "a file" : "#{files.size} files"}.</p>"
      request.notes.create!(body: text, kind: "email", source: "email from #{sender_name || sender_email}", occurred_at: mail.date || Time.current)
      request.record_event!("request.replied", actor: nil, source: "email", actor_label: sender_name || sender_email)
    end

    # The request a reply belongs to: its plus address (requests+r42-…@) on any recipient, else
    # the acknowledgement's Message-ID in In-Reply-To or References.
    def replied_to
      addresses = [ mail.to, mail.cc, mail["X-Original-To"]&.value, mail["Delivered-To"]&.value ].flatten.compact.join(" ")
      threads = [ mail.in_reply_to, mail.references ].flatten.compact.join(" ")

      [ addresses[REPLY_ADDRESS], threads[REPLY_MESSAGE_ID] ].compact.each do |match|
        id, token = match.match(Regexp.union(REPLY_ADDRESS, REPLY_MESSAGE_ID)).captures.compact
        request = Request.find_by_reply_token(id, token)
        return request if request
      end
      nil
    end

    # Files the sender attached, as the request's documents (internal until someone shares them).
    # Pictures inline in the message (signature logos) are skipped, and so is a file over the limit.
    def attach_files(request)
      mail.attachments.reject(&:inline?).filter_map do |attachment|
        document = request.documents.new(file: { io: StringIO.new(attachment.decoded), filename: attachment.filename, content_type: attachment.mime_type })
        document if document.save
      end
    end

    def title
      subject = mail.subject.to_s.sub(/\A(\s*(re|fwd?|aw|sv)\s*:\s*)+/i, "").squish
      (subject.presence || "Email from #{sender_name || sender_email}").truncate(200)
    end

    # Out-of-office and other machine replies say so in their headers (RFC 3834 and the usual
    # vendor ones); bounces come from the mail system.
    def automatic?
      submitted = mail["Auto-Submitted"]&.value.to_s.downcase
      precedence = mail["Precedence"]&.value.to_s.downcase

      (submitted.present? && submitted != "no") || mail["X-Autoreply"].present? || mail["X-Autorespond"].present? ||
        %w[bulk junk list auto_reply].include?(precedence) || mail["X-Auto-Response-Suppress"]&.value.to_s.match?(/\b(all|oof|autoreply)\b/i) ||
        sender_email.blank? || sender_email.match?(/\A(mailer-daemon|postmaster)@/)
    end

    # Our own mail, looping back through the requests address.
    def from_ourselves?
      setting = Setting.current
      ours = [ Mail::Address.new(setting.mail_sender).address, setting.requests_email ].compact.map(&:downcase)
      ours.include?(sender_email)
    end
end
