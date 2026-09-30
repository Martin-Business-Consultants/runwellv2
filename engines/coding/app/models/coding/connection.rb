module Coding
  # The agency's connection to GitHub (one row): its own OAuth app, the token of whoever
  # connected it, and the secret GitHub signs webhooks with. Everything GitHub does here
  # (pull requests, checks, deploys, issues, who can reach a repo) runs through it.
  class Connection < ::ApplicationRecord
    self.table_name = "coding_connections"

    encrypts :client_secret
    encrypts :access_token
    encrypts :webhook_secret

    normalizes :issue_label, with: ->(value) { value.to_s.strip.presence || "client" }

    validate :ensure_singleton, on: :create
    before_save { self.webhook_secret ||= SecureRandom.hex(32) }

    def self.current = first
    def self.for_settings = first || new

    def configured? = client_id.present? && client_secret.present?
    def connected? = configured? && access_token.present?

    def blocker
      return "no OAuth client id and secret have been saved" unless configured?
      return "nobody has signed in to GitHub yet" if access_token.blank?

      nil
    end

    def disconnect!
      update!(access_token: nil, login: nil, connected_at: nil, oauth_state: nil, last_error: nil)
    end

    def note_error!(message) = update_columns(last_error: message.to_s.truncate(500), updated_at: Time.current)
    def note_sync! = update!(last_synced_at: Time.current, last_error: nil)

    # GitHub signs each delivery with the secret: X-Hub-Signature-256 is "sha256=<hex hmac>".
    def verify_signature(body, signature)
      return false if webhook_secret.blank? || signature.blank?

      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, body)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
    end

    private
      def ensure_singleton
        errors.add(:base, "GitHub is already set up") if Connection.exists?
      end
  end
end
