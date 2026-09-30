module Quickbooks
  # The agency's connection to one QuickBooks company (one row). Two halves that arrive at
  # different times: the credentials of the agency's own Intuit app, pasted into Settings >
  # QuickBooks, then after Intuit's consent screen the tokens and the realm id that say which
  # company file this is.
  class Connection < ::ApplicationRecord
    self.table_name = "quickbooks_connections"

    # A client secret mints tokens, and an access token reads a company's whole books.
    encrypts :client_secret
    encrypts :access_token
    encrypts :refresh_token

    ENVIRONMENTS = %w[sandbox production].freeze

    # Intuit's access tokens last an hour. Refresh early: a sync that starts at 59 minutes
    # should not fail at 61.
    REFRESH_MARGIN = 5.minutes

    validates :environment, inclusion: { in: ENVIRONMENTS }
    validate :ensure_singleton, on: :create

    def self.current = first
    def self.for_settings = first || new(environment: "production")
    def self.ready? = current&.connected? || false

    def configured? = client_id.present? && client_secret.present?
    def connected? = configured? && realm_id.present? && refresh_token.present?
    def can_invoice? = connected? && default_item_id.present?
    def sandbox? = environment == "sandbox"

    # Pointing production credentials at the sandbox host answers with a confusing 401.
    def api_host = sandbox? ? "https://sandbox-quickbooks.api.intuit.com" : "https://quickbooks.api.intuit.com"

    def access_expired? = access_expires_at.nil? || access_expires_at <= REFRESH_MARGIN.from_now

    # The refresh token expires (~100 days) and rotates on every use, so a connection left
    # idle for months has to be re-consented rather than refreshed.
    def refresh_expired? = refresh_expires_at.present? && refresh_expires_at <= Time.current

    # Why this can't bill, in words, or nil when it can.
    def blocker
      return "no Intuit client id and secret have been saved" unless configured?
      return "nobody has signed in to QuickBooks yet" unless connected?
      return "QuickBooks needs reconnecting: the sign-in has expired" if refresh_expired?
      return "no product or service is chosen for invoice lines" if default_item_id.blank?

      nil
    end

    def store_tokens!(payload)
      update!(
        access_token: payload["access_token"],
        refresh_token: payload["refresh_token"].presence || refresh_token,
        access_expires_at: payload["expires_in"].to_i.seconds.from_now,
        refresh_expires_at: payload["x_refresh_token_expires_in"].presence&.to_i&.seconds&.from_now || refresh_expires_at,
        last_error: nil
      )
    end

    def disconnect!
      update!(realm_id: nil, company_name: nil, access_token: nil, refresh_token: nil, access_expires_at: nil,
        refresh_expires_at: nil, connected_at: nil, last_synced_at: nil, last_error: nil, last_sync_summary: nil, oauth_state: nil)
    end

    def note_error!(message) = update_columns(last_error: message.to_s.truncate(500), updated_at: Time.current)
    def note_sync!(summary) = update!(last_synced_at: Time.current, last_sync_summary: summary, last_error: nil)

    private
      def ensure_singleton
        errors.add(:base, "QuickBooks is already set up") if Connection.exists?
      end
  end
end
