module Outsend
  # The install's Outsend account: its API key (one row), and a note of the last message sent
  # and the last failure. The key may also come from the encrypted credentials
  # (outsend: api_key:, as Runwell v1 keeps it) or OUTSEND_API_KEY in the environment, for
  # installs that keep secrets there; a key saved here wins, then credentials, then the environment.
  class Connection < ::ApplicationRecord
    self.table_name = "outsend_connections"

    # Outsend's SMTP daemon: plain auth, the API key as the password, after STARTTLS (it refuses
    # auth without it).
    SMTP = { address: "smtp.getoutsend.com", port: 2587, user_name: "outsend", authentication: :plain,
             enable_starttls_auto: true, open_timeout: 5, read_timeout: 10 }.freeze

    encrypts :api_key

    validate :ensure_singleton, on: :create

    class << self
      def current = first
      def for_settings = first || new
      def record = first || create!

      # The key in use, if any.
      def key = current&.api_key.presence || credentials_key || ENV["OUTSEND_API_KEY"].presence

      # Where the key in use comes from: "settings", "credentials", "environment" or nil.
      def key_source
        if current&.api_key.present? then "settings"
        elsif credentials_key then "credentials"
        elsif ENV["OUTSEND_API_KEY"].present? then "environment"
        end
      end

      def credentials_key = Rails.application.credentials.dig(:outsend, :api_key).presence

      def smtp_settings(key) = SMTP.merge(password: key)

      def note_delivery!
        record.then { it.update_columns(last_delivered_at: Time.current, delivered_count: it.delivered_count + 1, last_error: nil, last_error_at: nil) }
      end

      def note_error!(message)
        record.update_columns(last_error: message.to_s.truncate(500), last_error_at: Time.current)
      end
    end

    def configured? = self.class.key.present?

    def forget_key! = update!(api_key: nil)

    private
      def ensure_singleton
        errors.add(:base, "There is already an Outsend connection") if Connection.exists?
      end
  end
end
