# The agency's connection to Google Ads (one row).
#
# Three credentials, and they are not interchangeable — which is worth saying
# because "it's 403" is the same symptom for all three being wrong:
#
#   client id + secret   the agency's own Google Cloud OAuth app, which is what
#                        a person consents to
#   developer token      approved once per agency in the Google Ads API Center;
#                        without it every call is PERMISSION_DENIED no matter
#                        how good the OAuth token is
#   login customer id    the manager (MCC) account the client accounts hang off
#
# Read-only, on purpose. Runwell shows a client what their advertising cost;
# changing a campaign happens in Google Ads, or in the ads app. Nothing here can
# write to an account, so a bug can be wrong but never expensive.
module GoogleAds
  class Connection < ApplicationRecord
    self.table_name = "google_ads_connections"

    # Each of these alone is enough to read an advertiser's whole account.
    encrypts :client_secret
    encrypts :developer_token
    encrypts :access_token
    encrypts :refresh_token

    # Google's access tokens last an hour. Refresh early rather than at the
    # boundary — a sync that starts at 59 minutes should not fail at 61.
    REFRESH_MARGIN = 5.minutes

    # Who to email when an ad account stops serving. Plain addresses rather than
    # user ids: the person who needs to know a client's card was declined is often
    # a billing contact who has no Runwell login at all. (Staff also see it on
    # the home page.)
    serialize :alert_recipients, coder: JSON

    validate :ensure_singleton, on: :create

    # Google sends customer ids as 123-456-7890 and people paste them that way;
    # the API only takes digits. Normalized on the way in so the two spellings
    # can't both end up in the column, which is the bug that makes every
    # `find_by(customer_id:)` blind to a duplicate.
    normalizes :login_customer_id, with: ->(value) { value.to_s.gsub(/[^0-9]/, "").presence }

    # Accepts an array or a typed, comma- or line-separated string.
    def alert_recipients=(value)
      super(case value
            when String then value.split(/[\n,]+/).map(&:strip).compact_blank
            when Array  then value.map(&:to_s).map(&:strip).compact_blank
            else value
            end)
    end

    def alert_recipient_list = Array(alert_recipients).compact_blank

    # An alert nobody receives is not an alert. Said out loud on the settings
    # page rather than discovered the month an account is suspended in silence.
    def alerts_configured? = alert_recipient_list.any?

    def self.current = first

    # Settings → Google Ads writes into this, so there is always a row to edit.
    def self.for_settings = first || new

    def configured? = client_id.present? && client_secret.present? && developer_token.present?
    def connected?  = configured? && refresh_token.present?

    def access_expired?
      access_expires_at.nil? || access_expires_at <= REFRESH_MARGIN.from_now
    end

    # Google does NOT rotate the refresh token, and only issues one at all on a
    # consent that asked for offline access. A refresh response therefore
    # carries no refresh_token at all, and treating that as "the token is gone"
    # is how a working connection erases itself an hour after it is made.
    def store_tokens!(payload)
      update!(
        access_token: payload["access_token"],
        refresh_token: payload["refresh_token"].presence || refresh_token,
        access_expires_at: payload["expires_in"].to_i.seconds.from_now,
        last_error: nil
      )
    end

    def disconnect!
      update!(access_token: nil, refresh_token: nil, access_expires_at: nil,
              connected_at: nil, last_synced_at: nil, last_error: nil,
              last_sync_summary: nil, oauth_state: nil)
    end

    def note_error!(message)
      update_columns(last_error: message.to_s.truncate(500), updated_at: Time.current)
    end

    # The counterpart, and the reason it exists: note_error! is called from the
    # settings page's own read, and nothing there ever cleared it again. A
    # failure that was fixed — a sunset API version, an expired token, a blip —
    # stayed on the page as a red paragraph forever, describing a problem that
    # no longer existed while everything behind it worked.
    def clear_error!
      return if last_error.blank?

      update_columns(last_error: nil, updated_at: Time.current)
    end

    def note_sync!(summary)
      update!(last_synced_at: Time.current, last_sync_summary: summary, last_error: nil)
    end

    # Why this connection can't read anything, in words, or nil when it can.
    # Each missing credential fails identically at Google — a 403 — so the
    # difference has to be said here or not at all.
    def blocker
      return "no OAuth client id and secret have been saved" if client_id.blank? || client_secret.blank?
      return "no developer token has been saved — Google rejects every call without one" if developer_token.blank?
      return "nobody has signed in to Google yet" if refresh_token.blank?

      nil
    end

    private

    def ensure_singleton
      errors.add(:base, "Google Ads is already set up") if Connection.exists?
    end
  end
end
