# An engagement pointed at a Google Ads account: "the Google Ads service for Summit is
# account 123-456-7890". One account per engagement; several engagements may share one.
module GoogleAds
  class Link < ApplicationRecord
    self.table_name = "google_ads_links"

    belongs_to :engagement, class_name: "::Engagement"
    belongs_to :linked_by, class_name: "::User", optional: true
    belongs_to :account, primary_key: :customer_id, foreign_key: :customer_id, optional: true, inverse_of: :links

    normalizes :customer_id, with: ->(value) { Client.normalize_customer_id(value) }

    validates :customer_id, presence: { message: "is needed: the 10-digit id Google shows as 123-456-7890" }
    validates :customer_id, format: { with: /\A\d{10}\z/, message: "should be 10 digits, like 123-456-7890" }, allow_blank: true
    validates :engagement_id, uniqueness: { message: "already has a Google Ads account" }

    scope :for_client, ->(client) { joins(:engagement).where(engagements: { client_id: client.id }) }

    def formatted_customer_id = Client.format_customer_id(customer_id)
    def label = account&.label || formatted_customer_id

    # This month so far and last month, for the summary cards.
    def this_month = Spend.for_account(customer_id).find_by(month: Date.current.beginning_of_month)
    def last_month = Spend.for_account(customer_id).find_by(month: Date.current.prev_month.beginning_of_month)
  end
end
