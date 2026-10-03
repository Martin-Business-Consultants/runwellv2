module SettingsHelper
  # A link in the Settings sidebar (settings/_nav), marked when it's the page on screen.
  def settings_nav_link(label, path, current:, icon: nil)
    link_to path, class: class_names("settings-nav__link", "settings-nav__link--nested": icon.nil?), aria: { current: ("page" if current) } do
      safe_join([ (icon_tag(icon) if icon), tag.span(label) ].compact)
    end
  end

  # The plugins nested under Plugins in the sidebar: each switched-on plugin with a settings
  # page, and the plugin on screen when it has only a details page. [key, label, url] each.
  def settings_nav_plugins(current)
    pages = Runwell::Plugins.enabled_settings_pages.filter_map do |key, (label, path)|
      url = instance_exec(&path)
      [ key, label, url ] if url
    end

    manifest = Runwell::Plugins.manifests[current.to_s.to_sym]
    pages << [ manifest.key, manifest.name, settings_plugin_path(manifest.key) ] if manifest && pages.none? { it.first == manifest.key }
    pages
  end

  INBOUND_INGRESSES = { postmark: "Postmark", mailgun: "Mailgun", sendgrid: "SendGrid", mandrill: "Mandrill", relay: "your mail server (relay)" }.freeze

  def inbound_ingress_name(ingress) = INBOUND_INGRESSES.fetch(ingress.to_sym, ingress.to_s)

  # The URL the inbound service posts mail to. Postmark, SendGrid and a relay sign in with the
  # ingress password as the actionmailbox user; Mailgun and Mandrill sign requests with their key.
  def inbound_ingress_url(ingress)
    case ingress.to_sym
    when :postmark then rails_postmark_inbound_emails_url.sub("://", "://actionmailbox:PASSWORD@")
    when :sendgrid then rails_sendgrid_inbound_emails_url.sub("://", "://actionmailbox:PASSWORD@")
    when :relay then rails_relay_inbound_emails_url.sub("://", "://actionmailbox:PASSWORD@")
    when :mailgun then rails_mailgun_inbound_emails_mime_url
    when :mandrill then rails_mandrill_inbound_emails_url
    else ""
    end
  end

  def inbound_ingress_secret_hint(ingress)
    case ingress.to_sym
    when :mailgun then "Mailgun signs each delivery: set MAILGUN_INGRESS_SIGNING_KEY to its webhook signing key."
    when :mandrill then "Mandrill signs each delivery: set MANDRILL_INGRESS_API_KEY to its API key."
    else "PASSWORD is RAILS_INBOUND_EMAIL_PASSWORD from the server’s environment: a long random string you choose."
    end
  end
end
