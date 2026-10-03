# Email's building blocks, with their styles written inline so Gmail and Outlook keep them
# (layouts/mailer adds only what inline styles can't: phones and dark mode). Every email is a
# heading, a few paragraphs, at most one button, and a reason in the footer:
#
#   <% content_for :preheader, "The line inboxes show after the subject" %>
#   <% content_for :reason, "Why this address got it" %>
#   <%= mail_heading "Review the website rebuild" %>
#   <p>…</p>
#   <%= mail_button "Review and approve", approval_url(token) %>
#
# Plugins' mailers inherit the layout and use the same helpers.
module MailerHelper
  def mail_brand_color = Setting.current.brand_color

  # The install's corners (Settings > Appearance) on the button.
  def mail_radius = { "sharp" => "3px", "round" => "999px" }.fetch(Setting.current.radius, "8px")

  def mail_heading(text)
    tag.h1 text, class: "mail-heading", style: "color:#16171a;font-size:22px;font-weight:700;line-height:1.3;letter-spacing:-0.01em;margin:0 0 16px;"
  end

  # A button that holds up in Outlook (a table cell carrying the color), then the address in
  # plain text for when the button doesn't work.
  def mail_button(text, url)
    radius = mail_radius
    button = tag.table(role: "presentation", cellpadding: 0, cellspacing: 0, border: 0, style: "margin:24px 0 8px;") do
      tag.tr do
        tag.td(bgcolor: mail_brand_color, style: "border-radius:#{radius};background:#{mail_brand_color};") do
          link_to text, url, class: "mail-button", style: "display:inline-block;padding:12px 24px;border-radius:#{radius};color:#ffffff;font-size:16px;font-weight:600;line-height:1.2;text-decoration:none;"
        end
      end
    end
    fallback = tag.p(class: "mail-muted", style: "color:#8a8c93;font-size:13px;line-height:1.5;margin:0 0 16px;word-break:break-all;") do
      safe_join([ "Button not working? Paste this into your browser: ", link_to(url, url, style: "color:#8a8c93;") ])
    end
    button + fallback
  end

  # Someone's words quoted: a mention, a request's title.
  def mail_quote(text)
    tag.div text, class: "mail-quote", style: "border-left:3px solid #{mail_brand_color};color:#3a3b40;margin:0 0 16px;padding:4px 0 4px 14px;"
  end

  def mail_small(text = nil, &)
    tag.p (text || capture(&)), class: "mail-muted", style: "color:#8a8c93;font-size:13px;line-height:1.5;margin:0 0 16px;"
  end
end
