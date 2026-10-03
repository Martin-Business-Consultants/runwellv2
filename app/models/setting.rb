# This install's settings: what it calls things, who its mail comes from, and which plugins
# are switched on. One row: one install is one agency.
class Setting < ApplicationRecord
  TERMS = %w[client engagement scope_item work].freeze
  INDEX_VIEWS = %w[cards table].freeze

  THEMES = { "system" => "System", "light" => "Light", "dark" => "Dark" }.freeze
  RADII = { "sharp" => "Sharp", "fizzy" => "Soft", "round" => "Round" }.freeze
  SCHEMES = { "fizzy" => "Indigo", "forest" => "Forest", "plum" => "Plum", "ocean" => "Ocean", "graphite" => "Graphite" }.freeze
  # Each scheme's accent as hex (its oklch in appearance.css, converted), for email, which knows
  # neither oklch nor CSS variables.
  SCHEME_COLORS = { "fizzy" => "#5d63cd", "forest" => "#058931", "plum" => "#a049d4", "ocean" => "#00859a", "graphite" => "#404249" }.freeze
  FONTS = { "system" => "System", "humanist" => "Humanist", "rounded" => "Rounded", "serif" => "Serif", "mono" => "Mono" }.freeze

  has_one_attached :logo
  has_one_attached :favicon

  validates :index_view, inclusion: { in: INDEX_VIEWS }
  validates :theme, inclusion: { in: THEMES.keys }
  validates :radius, inclusion: { in: RADII.keys }
  validates :scheme, inclusion: { in: SCHEMES.keys }
  validates :font, inclusion: { in: FONTS.keys }

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
