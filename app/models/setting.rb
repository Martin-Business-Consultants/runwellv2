# This install's settings: what it calls things, who its mail comes from, and which plugins
# are switched on. One row: one install is one business (or household, or whatever it runs).
class Setting < ApplicationRecord
  include CustomCss, Start, Eventful

  TERMS = %w[client engagement scope_item work commitment].freeze
  INDEX_VIEWS = %w[cards table].freeze

  THEMES = { "system" => "System", "light" => "Light", "dark" => "Dark" }.freeze
  RADII = { "sharp" => "Sharp", "fizzy" => "Soft", "round" => "Round" }.freeze
  SCHEMES = { "fizzy" => "Indigo", "forest" => "Forest", "plum" => "Plum", "ocean" => "Ocean", "graphite" => "Graphite" }.freeze
  # Each scheme's accent as hex (its oklch in appearance.css, converted), for email, which knows
  # neither oklch nor CSS variables.
  SCHEME_COLORS = { "fizzy" => "#5d63cd", "forest" => "#058931", "plum" => "#a049d4", "ocean" => "#00859a", "graphite" => "#404249" }.freeze
  # Text size: the page's base size, which every rem in the stylesheets scales from (Default is
  # 16px, with the body text at 14px). Each person may pick their own (User#text_size, Settings > Your account).
  TEXT_SIZES = { "small" => "Small", "default" => "Default", "large" => "Large", "larger" => "Larger" }.freeze
  FONTS = { "system" => "System", "humanist" => "Humanist", "rounded" => "Rounded", "serif" => "Serif", "mono" => "Mono" }.freeze

  has_one_attached :logo
  has_one_attached :favicon

  validates :index_view, inclusion: { in: INDEX_VIEWS }
  validates :theme, inclusion: { in: THEMES.keys }
  validates :radius, inclusion: { in: RADII.keys }
  validates :scheme, inclusion: { in: SCHEMES.keys }
  validates :font, inclusion: { in: FONTS.keys }
  validates :text_size, inclusion: { in: TEXT_SIZES.keys }

  normalizes :mail_from_name, :mail_from_email, with: ->(value) { value.to_s.strip.presence }
  validates :mail_from_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "should be an email address" }, allow_nil: true

  # Where people reach this install (Settings > Address), typed as a host or a whole URL.
  normalizes :app_host, with: ->(value) { value.to_s.strip.downcase.sub(%r{\A[a-z]+://}, "").sub(%r{[/?#].*\z}, "").presence }
  validates :app_host, format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(:\d+)?\z/, message: "should be a domain, like runwell.example.com" }, allow_nil: true
  validates :app_protocol, inclusion: { in: %w[https http] }, allow_nil: true

  # Takes "https://runwell.example.com/" or a bare host, which means https.
  def app_url=(url)
    self.app_protocol = url.to_s.strip[%r{\A(https?)://}i, 1]&.downcase || "https"
    self.app_host = url
  end

  def self.human_attribute_name(attribute, options = {}) = attribute.to_s == "app_host" ? "Address" : super

  def self.current
    Current.settings ||= first_or_create!
  end

  # The install's time zone: what your pages, agent answers and emails use (a client may have its
  # own, Client#time_zone). Saved here it wins over TIME_ZONE in the environment, which is the default.
  validates :time_zone, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:name) + TZInfo::Timezone.all_identifiers }, message: "isn’t a time zone we know" }, allow_nil: true
  normalizes :time_zone, with: ->(value) { value.presence && (ActiveSupport::TimeZone::MAPPING.key(value) || value) }

  def self.zone = ActiveSupport::TimeZone[current.time_zone.presence || Time.zone_default.name] || Time.zone_default
  def self.time_zone_set? = current.time_zone.present? || ENV["TIME_ZONE"].present?

  # The outgoing mail server, when the environment names none (SMTP_* wins): Settings > Email.
  SMTP_SECURITIES = { "starttls" => "STARTTLS (usually port 587)", "tls" => "TLS (usually port 465)", "none" => "None" }.freeze
  encrypts :smtp_password
  normalizes :smtp_address, :smtp_username, with: ->(value) { value.to_s.strip.presence }
  validates :smtp_security, inclusion: { in: SMTP_SECURITIES.keys }
  validates :smtp_port, numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }, allow_nil: true

  def self.smtp_from_environment? = ENV["SMTP_ADDRESS"].present?

  # Settings for Mail's SMTP delivery from what's saved here, or nil when nothing is.
  def smtp_settings
    return if smtp_address.blank?

    { address: smtp_address, port: smtp_port || (smtp_security == "tls" ? 465 : 587), user_name: smtp_username, password: smtp_password.presence,
      authentication: (:plain if smtp_username.present?), enable_starttls_auto: smtp_security == "starttls", tls: smtp_security == "tls",
      open_timeout: 5, read_timeout: 10 }.compact
  end

  # How requests' mail reaches Runwell (Action Mailbox): the service forwarding it, and the password
  # it signs in with. The server's environment wins (INBOUND_EMAIL_INGRESS, RAILS_INBOUND_EMAIL_PASSWORD);
  # otherwise Settings > Email or a plugin (Cloudflare) sets them here, with no restart.
  INBOUND_INGRESSES = %w[relay postmark sendgrid mailgun mandrill].freeze
  encrypts :inbound_password
  validates :inbound_ingress, inclusion: { in: INBOUND_INGRESSES }, allow_nil: true
  normalizes :inbound_ingress, with: ->(value) { value.to_s.strip.presence }

  def self.inbound_ingress = Rails.configuration.action_mailbox.ingress.presence&.to_sym || current.inbound_ingress&.to_sym
  def self.inbound_from_environment? = Rails.configuration.action_mailbox.ingress.present?
  def self.inbound_password = Rails.application.credentials.dig(:action_mailbox, :ingress_password).presence || ENV["RAILS_INBOUND_EMAIL_PASSWORD"].presence || current.inbound_password.presence

  # Receive through a service: kept here (unless the environment names one), with a password made
  # for it if there's none yet. Answers the password, for whatever forwards the mail.
  def receive_mail_through!(ingress)
    update!(inbound_ingress: ingress.to_s, inbound_password: inbound_password.presence || SecureRandom.hex(32))
    self.class.inbound_password
  end

  # Where clients email requests (RequestsMailbox), and each request's reply address on it.
  normalizes :requests_email, with: ->(value) { value.to_s.strip.downcase.presence }
  validates :requests_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "should be an email address" }, allow_nil: true

  def requests_reply_address(request)
    local, domain = requests_email.split("@", 2)
    "#{local.split("+").first}+r#{request.id}-#{request.reply_token}@#{domain}"
  end

  def brand_color = SCHEME_COLORS.fetch(scheme, SCHEME_COLORS["fizzy"])

  # Who the install is, in words: the sender's name (Settings > Email), else Runwell.
  def brand_name = Mail::Address.new(mail_sender).display_name.presence || "Runwell"

  # The sender when Settings > Email is blank: MAIL_FROM, or a no-reply address at the host.
  def self.default_mail_sender
    ENV.fetch("MAIL_FROM") { "Runwell <no-reply@#{Runwell.host}>" }
  end

  # Who mail comes from, "Name <address>": the name and address set here, each falling back
  # to its half of the default sender, however the mail is delivered.
  def mail_sender
    default = Mail::Address.new(self.class.default_mail_sender)
    Mail::Address.new(mail_from_email || default.address).tap do |sender|
      sender.display_name = mail_from_name || default.display_name
    end.to_s
  end

  # The name for a core thing: this install's word if it set one, else the default.
  def term(key, count: 1)
    form = count == 1 ? "one" : "other"
    terminology.dig(key.to_s, form).presence || I18n.t("terms.#{key}.#{form}")
  end

  def label_name(label, count: 1)
    form = count == 1 ? "one" : "other"
    terminology.dig("labels", label.to_s, form).presence || I18n.t("terms.labels.#{label}.#{form}")
  end

  def label_prefix(label)
    terminology.dig("labels", label.to_s, "prefix").presence&.upcase || I18n.t("terms.labels.#{label}.prefix")
  end

  def label_enabled?(label)
    terminology.dig("labels", label.to_s, "enabled") != false
  end

  # Settings > Sign-in > Only sign in through these: passwords and emailed links are for owners alone.
  def password_sign_in_for?(user) = !providers_only? || user.owner?

  def enabled_labels
    Engagement::LABELS.select { label_enabled?(it) }
  end

  # A plugin is on or off as the owner set it, else as its manifest says. Plugins are off
  # until switched on, like an installed but inactive WordPress plugin.
  def plugin_enabled?(key, default: false)
    plugin_states.fetch(key.to_s, default)
  end

  def toggle_plugin!(key, enabled:)
    update!(plugin_states: plugin_states.merge(key.to_s => enabled))
  end
end
