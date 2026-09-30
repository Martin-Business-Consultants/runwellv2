module AccountManagement
  # One of a client's outside accounts: a Facebook page, an Instagram account, an ad account, a
  # pixel, an analytics property, a domain. The register answers who owns it (the client, us, or
  # a third party such as a former agency), what access we hold, where its login lives, when its
  # token expires and when someone last checked all of that. Never the password or the token
  # itself: login_location says where to find them (“Bitwarden › BioFuse › Meta”).
  class Access < ::ApplicationRecord
    include ::Eventful

    PLATFORMS = {
      "facebook_page" => "Facebook page", "instagram" => "Instagram account", "meta_business" => "Meta business portfolio",
      "meta_ad_account" => "Meta ad account", "meta_pixel" => "Meta pixel / Conversions API",
      "google_ads" => "Google Ads account", "google_analytics" => "Google Analytics property", "tag_manager" => "Google Tag Manager",
      "search_console" => "Google Search Console", "business_profile" => "Google Business Profile",
      "domain" => "Domain / DNS", "hosting" => "Hosting", "email" => "Email sending", "crm" => "CRM", "other" => "Other"
    }.freeze
    OWNED_BY = { "client" => "The client", "us" => "Us", "third_party" => "A third party", "unknown" => "Not known" }.freeze
    OUR_ACCESS = { "none" => "None", "requested" => "Requested", "partner" => "Partner / limited", "admin" => "Admin", "owner" => "Owner" }.freeze

    belongs_to :client, class_name: "::Client"
    belongs_to :verified_by, class_name: "::User", optional: true

    validates :name, presence: true
    validates :platform, inclusion: { in: PLATFORMS.keys }
    validates :owned_by, inclusion: { in: OWNED_BY.keys }
    validates :our_access, inclusion: { in: OUR_ACCESS.keys }
    validates :owner_name, presence: { message: "can’t be blank: name the third party that owns it" }, if: -> { owned_by == "third_party" }
    validates :url, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_blank: true

    scope :ordered, -> { order(:platform, :name) }

    def self.for(record) = record.is_a?(::Client) ? where(client: record) : none

    def platform_label = PLATFORMS.fetch(platform, platform.humanize)
    def owned_by_label = owned_by == "third_party" ? owner_name.presence || "A third party" : OWNED_BY.fetch(owned_by)
    def our_access_label = OUR_ACCESS.fetch(our_access)

    # What's wrong with it, in words, worst first. Empty when it's in order.
    def problems
      [
        ("Owned by #{owner_name.presence || "a third party"}: get it moved to the client" if owned_by == "third_party"),
        ("Nobody knows who owns it" if owned_by == "unknown"),
        ("We have no access" if our_access == "none"),
        ("Our access is only requested" if our_access == "requested"),
        token_problem,
        ("Never checked" if verified_on.nil?),
        ("Last checked #{verified_on.to_fs(:long)}" if stale?)
      ].compact
    end

    def in_order? = problems.empty?

    def token_problem
      return if token_expires_on.nil?

      if token_expires_on < Date.current then "Token expired #{token_expires_on.to_fs(:long)}"
      elsif token_expires_on <= Date.current + Playbook::TOKEN_WARNING then "Token expires #{token_expires_on.to_fs(:long)}"
      end
    end

    def stale? = verified_on.present? && verified_on < Date.current - Playbook::VERIFY_EVERY

    # Someone looked today: the owner, our access and the token are as recorded.
    def verify!(by: Current.user, source: Current.source)
      transaction do
        update!(verified_on: Date.current, verified_by: by)
        record_event!("access.verified", actor: by, source: source || "app", payload: { owned_by: owned_by_label, our_access: our_access_label })
      end
    end
  end
end
