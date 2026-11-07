# A client's email, as a request: work on the sender's client (matched by their address, else
# none until someone picks one) that nobody has taken on yet. The subject is the title, the body the description, cleaned of quoted mail and signatures (Task::EmailBody), and
# attachments become its documents. Automatic replies and our own mail are dropped. A known contact gets a short
# acknowledgement.
class RequestsMailbox < ApplicationMailbox
  def process
    return if automatic? || from_ourselves?

    Current.set(source: "email") { receive_request }
  end

  private
    def sender_email = mail.from_address&.address.to_s.downcase
    def sender_name = mail.from_address&.display_name.presence || mail[:from]&.display_names&.first.presence
    def body = @body ||= Task::EmailBody.new(mail)

    def receive_request
      request = Task.create!(title: title, description: body.to_html, sender_name: sender_name, sender_email: sender_email,
                             source: "email", created_at: mail.date || Time.current)
      attach_files(request)
      request.record_event!("task.requested", actor: nil, source: "email", actor_label: request.requester_name)

      if request.contact && Setting.current.requests_email.present?
        RequestMailer.with(task: request, in_reply_to: mail.message_id).received.deliver_later
      end
    end

    # Files the sender attached, as the work's documents (internal until someone shares them).
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
