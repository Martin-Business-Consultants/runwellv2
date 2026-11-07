# Mail (Settings > Email): who it comes from, the outgoing server when the environment names none,
# how requests' mail comes in, and the address clients email requests to.
module Setting::Mail
  extend ActiveSupport::Concern

  SMTP_SECURITIES = { "starttls" => "STARTTLS (usually port 587)", "tls" => "TLS (usually port 465)", "none" => "None" }.freeze
  INBOUND_INGRESSES = %w[relay postmark sendgrid mailgun mandrill].freeze

  included do
    normalizes :mail_from_name, :mail_from_email, with: ->(value) { value.to_s.strip.presence }
    validates :mail_from_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "should be an email address" }, allow_nil: true

    encrypts :smtp_password
    normalizes :smtp_address, :smtp_username, with: ->(value) { value.to_s.strip.presence }
    validates :smtp_security, inclusion: { in: SMTP_SECURITIES.keys }
    validates :smtp_port, numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }, allow_nil: true

    encrypts :inbound_password
    validates :inbound_ingress, inclusion: { in: INBOUND_INGRESSES }, allow_nil: true
    normalizes :inbound_ingress, with: ->(value) { value.to_s.strip.presence }

    normalizes :requests_email, with: ->(value) { value.to_s.strip.downcase.presence }
    validates :requests_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "should be an email address" }, allow_nil: true
  end

  class_methods do
    def smtp_from_environment? = ENV["SMTP_ADDRESS"].present?

    # How requests' mail reaches Runwell (Action Mailbox): the service forwarding it, and the
    # password it signs in with. The server's environment wins (INBOUND_EMAIL_INGRESS,
    # RAILS_INBOUND_EMAIL_PASSWORD); otherwise Settings > Email or a plugin (Cloudflare) sets them
    # here, with no restart.
    def inbound_ingress = Rails.configuration.action_mailbox.ingress.presence&.to_sym || current.inbound_ingress&.to_sym
    def inbound_from_environment? = Rails.configuration.action_mailbox.ingress.present?
    def inbound_password = Rails.application.credentials.dig(:action_mailbox, :ingress_password).presence || ENV["RAILS_INBOUND_EMAIL_PASSWORD"].presence || current.inbound_password.presence

    # The sender when Settings > Email is blank: MAIL_FROM, or a no-reply address at the host.
    def default_mail_sender
      ENV.fetch("MAIL_FROM") { "Runwell <no-reply@#{Runwell.host}>" }
    end
  end

  # Settings for Mail's SMTP delivery from what's saved here, or nil when nothing is.
  def smtp_settings
    return if smtp_address.blank?

    { address: smtp_address, port: smtp_port || (smtp_security == "tls" ? 465 : 587), user_name: smtp_username, password: smtp_password.presence,
      authentication: (:plain if smtp_username.present?), enable_starttls_auto: smtp_security == "starttls", tls: smtp_security == "tls",
      open_timeout: 5, read_timeout: 10 }.compact
  end

  # Receive through a service: kept here (unless the environment names one), with a password made
  # for it if there's none yet. Answers the password, for whatever forwards the mail.
  def receive_mail_through!(ingress)
    update!(inbound_ingress: ingress.to_s, inbound_password: inbound_password.presence || SecureRandom.hex(32))
    self.class.inbound_password
  end

  # Who mail comes from, "Name <address>": the name and address set here, each falling back
  # to its half of the default sender, however the mail is delivered.
  def mail_sender
    default = ::Mail::Address.new(self.class.default_mail_sender)
    ::Mail::Address.new(mail_from_email || default.address).tap do |sender|
      sender.display_name = mail_from_name || default.display_name
    end.to_s
  end

  # Who the install is, in words: the sender's name, else Runwell.
  def brand_name = ::Mail::Address.new(mail_sender).display_name.presence || "Runwell"
end
