# What we know about one Google Ads account, apart from what it spent: its name, its
# currency, and whether it is still able to serve ads.
#
# On "card declined": the Google Ads API has no field for it. What the API does say is that
# the account has left ENABLED, which is what a declined card causes within a day or two. So
# that is what is detected and what the alert says ("stopped serving", never "your card was
# declined"), because the same status covers an account someone cancelled on purpose.
module GoogleAds
  class Account < ApplicationRecord
    self.table_name = "google_ads_accounts"

    # Google's own vocabulary for customer.status.
    SERVING = "ENABLED"
    # The ones that mean the ads have stopped. UNKNOWN is deliberately not here: it is what an
    # unreadable response looks like.
    BLOCKED = %w[SUSPENDED CANCELED CLOSED].freeze

    EXPLANATIONS = {
      "SUSPENDED" => "Google has suspended it. That is usually a payment that didn’t go through: " \
                     "check the card on file in Google Ads → Billing.",
      "CANCELED" => "The account has been cancelled.",
      "CLOSED" => "The account has been closed."
    }.freeze

    has_many :links, primary_key: :customer_id, foreign_key: :customer_id, inverse_of: false

    validates :customer_id, presence: true, uniqueness: true

    normalizes :customer_id, with: ->(value) { Client.normalize_customer_id(value) }

    scope :blocked, -> { where(status: BLOCKED) }

    def serving? = status == SERVING

    # Not `!serving?`: an account never read, or UNKNOWN, is not known to be blocked.
    def blocked? = BLOCKED.include?(status)

    def explanation = EXPLANATIONS[status] || "It is no longer able to run ads."

    def label = descriptive_name.presence || formatted_customer_id

    def formatted_customer_id = Client.format_customer_id(customer_id)

    # The engagements (and clients) that stop getting results if this account does.
    def engagements = ::Engagement.where(id: links.select(:engagement_id)).includes(:client)

    # Record what Google says, and answer whether this is the moment it stopped. Only a
    # transition INTO a blocked state is news; a suspended account is still suspended tomorrow.
    def note_status!(new_status, synced_at: Time.current)
      became_blocked = BLOCKED.include?(new_status) && !blocked?

      attrs = { status: new_status, synced_at: synced_at }
      attrs[:status_changed_at] = synced_at if new_status != status
      # Cleared on recovery so the NEXT suspension is alerted afresh.
      attrs[:alerted_at] = nil if new_status == SERVING

      update!(attrs)
      became_blocked
    end

    def note_alerted! = update!(alerted_at: Time.current)
  end
end
