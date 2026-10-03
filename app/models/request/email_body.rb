# What a client wrote in an email, without the rest: the quoted mail below a reply ("On … wrote:",
# Outlook's "From: … Sent:" block, "-----Original Message-----", > lines), the signature after
# "-- ", and "Sent from my iPhone". Taken from the plain text part when there is one, else from
# the HTML with its quote and signature blocks removed. As HTML paragraphs for the rich text field.
class Request::EmailBody
  QUOTE_STARTS = [
    /^On\b.{0,200}\bwrote:\s*$/im,                       # Gmail, Apple Mail (may wrap onto two lines)
    /^-{2,}\s*Original Message\s*-{2,}/i,                 # Outlook, older clients
    /^_{10,}\s*$/,                                        # Outlook's rule above the quoted message
    /^From:\s.+\n(Sent|Date):\s/i,                        # Outlook's header block
    /^-{2,}\s*Forwarded message\s*-{2,}/i,
    /^Sent from my \w+/i,
    /^Get Outlook for /i,
    /^-- ?$/                                              # signature delimiter
  ].freeze

  HTML_QUOTES = ".gmail_quote, .gmail_signature, blockquote, .yahoo_quoted, #appendonsend, #divRplyFwdMsg, " \
                "#Signature, .moz-cite-prefix, .moz-signature, div[name=messageReplySection], style, script, head, title"

  def initialize(mail)
    @mail = mail
  end

  def text
    @text ||= clean(raw)
  end

  def to_html
    text.split(/\n{2,}/).map { "<p>#{ERB::Util.html_escape(it).gsub("\n", "<br>")}</p>" }.join
  end

  private
    def raw
      if (part = @mail.text_part || (@mail.mime_type == "text/plain" && @mail))
        decode(part)
      elsif (part = @mail.html_part || (@mail.mime_type == "text/html" && @mail))
        html_to_text(decode(part))
      else
        ""
      end
    end

    def decode(part)
      part.decoded.to_s.dup.force_encoding(part.charset.presence || "UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    rescue Encoding::ConverterNotFoundError, ArgumentError
      part.decoded.to_s.dup.force_encoding("UTF-8").scrub("")
    end

    def html_to_text(html)
      document = Nokogiri::HTML(html)
      document.css(HTML_QUOTES).each(&:remove)
      document.css("#appendonsend ~ *, hr ~ *").each(&:remove)
      document.css("br").each { it.replace("\n") }
      document.css("p, div, li, tr, h1, h2, h3, h4, h5, h6").each { it.add_next_sibling("\n\n") }
      document.text
    end

    def clean(text)
      text = text.gsub(/\r\n?/, "\n").gsub(/ /, " ")
      cut = QUOTE_STARTS.filter_map { text.index(it) }.min
      text = text[0...cut] if cut
      text.lines.reject { it.start_with?(">") }.join
        .gsub(/[ \t]+$/, "").gsub(/\n{3,}/, "\n\n").strip
    end
end
